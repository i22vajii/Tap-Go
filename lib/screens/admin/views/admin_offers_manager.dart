import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../config/app_colors.dart'; 
import '../../common/qr_scanner_screen.dart';

class AdminOffersManager extends StatefulWidget {
  const AdminOffersManager({super.key});

  @override
  State<AdminOffersManager> createState() => _AdminOffersManagerState();
}

class _AdminOffersManagerState extends State<AdminOffersManager> {
  // Referencia a la colección de Firebase
  final CollectionReference _ofertasRef = 
      FirebaseFirestore.instance.collection('ofertas');

  // Función para obtener el shopID del Admin actual
  Future<String?> _getAdminShopId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance.collection('owners').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      // Buscamos 'shopID' (como en tu código de guardar) o 'shop_ID' (por seguridad)
      return data['shopID']?.toString() ?? data['shop_ID']?.toString(); 
    }
    return null;
  }

  // --- LÓGICA DE FIREBASE ---

  // 1. Guardar nueva oferta
  Future<void> _subirOferta(String titulo, String codigo, bool activa) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('owners').doc(user.uid).get();
      if (!userDoc.exists) throw Exception("No owner found");

      final userData = userDoc.data() as Map<String, dynamic>;
      // Asegúrate de usar el mismo nombre de campo siempre
      final String? shopId = userData['shopID'] ?? userData['shop_ID']; 

      if (shopId == null || shopId.isEmpty) throw Exception("No shopID found");

      await _ofertasRef.add({
        'titulo': titulo,
        'codigo': codigo,
        'activa': activa,
        'shopID': shopId, 
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Oferta creada para: $shopId"), backgroundColor: AppColors.turquesaVivo)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // 2. Cambiar visibilidad
  Future<void> _cambiarEstadoOferta(String id, bool nuevoEstado) async {
    await _ofertasRef.doc(id).update({'activa': nuevoEstado});
  }

  // 3. Diálogo de creación
  void _mostrarDialogoNuevaOferta() {
    String nuevoTitulo = "";
    String nuevoCodigo = "";
    bool estaActiva = false; 

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Nueva Oferta"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: "Nombre", prefixIcon: Icon(Icons.abc)),
                    onChanged: (val) => nuevoTitulo = val,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(labelText: "Código QR", prefixIcon: Icon(Icons.qr_code)),
                    onChanged: (val) => nuevoCodigo = val,
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: Text(estaActiva ? "Visible" : "Borrador", style: TextStyle(color: estaActiva ? AppColors.turquesaVivo : Colors.grey)),
                    value: estaActiva,
                    activeColor: AppColors.turquesaVivo,
                    onChanged: (val) => setState(() => estaActiva = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.turquesaVivo),
                  onPressed: () {
                    if (nuevoTitulo.isNotEmpty && nuevoCodigo.isNotEmpty) {
                      _subirOferta(nuevoTitulo, nuevoCodigo, estaActiva);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Guardar", style: TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }

  // --- INTERFAZ DE USUARIO ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión Ofertas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              // USAMOS LA VISTA COMPARTIDA
              final codigoLeido = await Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const QrScannerScreen())
              );
              
              if (codigoLeido != null && codigoLeido is String && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Cupón: $codigoLeido"), backgroundColor: AppColors.turquesaVivo)
                );
              }
            },
          )
        ],
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoNuevaOferta,
        backgroundColor: AppColors.turquesaVivo,
        label: const Text("NUEVA OFERTA", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
      
      body: FutureBuilder<String?>(
        future: _getAdminShopId(),
        builder: (context, userSnapshot) {
          
          // 1. Cargando perfil del admin...
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error o no hay Shop ID
          if (userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data == null) {
            return Center(
              child: Text(
                "Error: No se encontró un shopID asociado a este administrador.\nRevisa la colección 'owners'.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          final String myShopId = userSnapshot.data!;

          // 3. Ya tenemos el ID, ahora cargamos el Stream filtrado
          return StreamBuilder(
            stream: _ofertasRef
                .where('shopID', isEqualTo: myShopId) // <--- FILTRO: Solo mis ofertas
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.hasError) {
                return Center(child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text("Error de carga. Si ves un enlace en la consola, haz clic para crear el índice.\nError: ${snapshot.error}", textAlign: TextAlign.center),
                ));
              }
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_offer_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text("No tienes ofertas creadas para la tienda:\n$myShopId", 
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600])
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(20),
                children: snapshot.data!.docs.map((doc) {
                  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                  return _offerItem(doc.id, data);
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }

  // Tarjeta individual
  Widget _offerItem(String id, Map<String, dynamic> data) {
    bool activa = data['activa'] ?? false;
    
    return Card(
      elevation: activa ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: activa ? Colors.white : Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: activa ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => _verQR(data['titulo'], data['codigo']),
            leading: CircleAvatar(
              backgroundColor: activa ? AppColors.aquaSuave : Colors.grey[300],
              child: Icon(Icons.local_offer, color: activa ? AppColors.azulProfundo : Colors.grey),
            ),
            title: Text(
              data['titulo'], 
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: activa ? null : TextDecoration.lineThrough,
                color: activa ? AppColors.azulMedianoche : Colors.grey,
              )
            ),
            subtitle: Text("Código: ${data['codigo']}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: activa,
                  activeColor: AppColors.turquesaVivo,
                  onChanged: (val) => _cambiarEstadoOferta(id, val),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.alertaRojo),
                  onPressed: () => _confirmarBorrado(id),
                ),
              ],
            ),
          ),
          if (!activa)
             Container(
               width: double.infinity,
               decoration: BoxDecoration(
                 color: Colors.grey[300],
                 borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))
               ),
               padding: const EdgeInsets.symmetric(vertical: 4),
               child: const Text("BORRADOR (OCULTO)", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
             )
        ],
      ),
    );
  }

  void _confirmarBorrado(String id) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar?"),
        content: const Text("Se borrará permanentemente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              _ofertasRef.doc(id).delete();
              Navigator.pop(ctx);
            }, 
            child: const Text("Eliminar", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }

  void _verQR(String titulo, String codigo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(20),
        title: Text(titulo, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mantenemos QrImageView de qr_flutter para MOSTRAR el código
            SizedBox(width: 200, height: 200, child: QrImageView(data: codigo, size: 200)),
            const SizedBox(height: 10),
            Text(codigo, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar"))],
      ),
    );
  }
}