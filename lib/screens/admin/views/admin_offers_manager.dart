import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../config/app_colors.dart';
import '../../../services/offers_service.dart';
import '../../common/qr_scanner_screen.dart';

class AdminOffersManager extends StatefulWidget {
  const AdminOffersManager({super.key});

  @override
  State<AdminOffersManager> createState() => _AdminOffersManagerState();
}

class _AdminOffersManagerState extends State<AdminOffersManager> {
  // Instancia del servicio
  final OffersService _offersService = OffersService();

  // --- LÓGICA DE INTERACCIÓN (Wrappers para el Servicio) ---

  Future<void> _subirOferta(String shopId, String titulo, String codigo, bool activa) async {
    try {
      await _offersService.createOffer(
        shopId: shopId, 
        title: titulo, 
        code: codigo, 
        isActive: activa
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Oferta creada correctamente"), backgroundColor: AppColors.turquesaVivo)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _cambiarEstadoOferta(String id, bool nuevoEstado) async {
    try {
      await _offersService.toggleOfferStatus(id, nuevoEstado);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error actualizando: $e")));
    }
  }

  Future<void> _borrarOferta(String id) async {
    try {
      await _offersService.deleteOffer(id);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error eliminando: $e")));
    }
  }

  // --- UI DIÁLOGOS ---

  void _mostrarDialogoNuevaOferta(String shopId) {
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
                      _subirOferta(shopId, nuevoTitulo, nuevoCodigo, estaActiva);
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
              _borrarOferta(id);
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
            SizedBox(width: 200, height: 200, child: QrImageView(data: codigo, size: 200)),
            const SizedBox(height: 10),
            Text(codigo, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar"))],
      ),
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    // 1. Primero resolvemos el ShopID
    return FutureBuilder<String>(
      future: _offersService.getAdminShopId(),
      builder: (context, userSnapshot) {
        
        // Estado: Cargando ID
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Estado: Error obteniendo ID
        if (userSnapshot.hasError || !userSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text("Gestión Ofertas")),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  "Error de acceso: ${userSnapshot.error ?? 'No se encontró tienda'}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          );
        }

        final String myShopId = userSnapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Gestión Ofertas"),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () async {
                  final codigoLeido = await Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const QrScannerScreen())
                  );
                  
                  if (codigoLeido != null && codigoLeido is String && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Cupón escaneado: $codigoLeido"), backgroundColor: AppColors.turquesaVivo)
                    );
                  }
                },
              )
            ],
          ),
          
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _mostrarDialogoNuevaOferta(myShopId),
            backgroundColor: AppColors.turquesaVivo,
            label: const Text("NUEVA OFERTA", style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.add, color: Colors.white),
          ),
          
          // 2. Cargamos el Stream de Ofertas usando el ID obtenido
          body: StreamBuilder<List<OfferModel>>(
            stream: _offersService.getAdminOffersStream(myShopId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Error cargando lista: ${snapshot.error}"));
              }
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_offer_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text("No tienes ofertas creadas para:\n$myShopId", 
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600])
                      ),
                    ],
                  ),
                );
              }

              final offers = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: offers.length,
                itemBuilder: (context, index) => _offerItem(offers[index]),
              );
            },
          ),
        );
      },
    );
  }

  // Tarjeta individual (Usa OfferModel en lugar de Map)
  Widget _offerItem(OfferModel offer) {
    return Card(
      elevation: offer.isActive ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: offer.isActive ? Colors.white : Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: offer.isActive ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => _verQR(offer.title, offer.code),
            leading: CircleAvatar(
              backgroundColor: offer.isActive ? AppColors.aquaSuave : Colors.grey[300],
              child: Icon(Icons.local_offer, color: offer.isActive ? AppColors.azulProfundo : Colors.grey),
            ),
            title: Text(
              offer.title, 
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: offer.isActive ? null : TextDecoration.lineThrough,
                color: offer.isActive ? AppColors.azulMedianoche : Colors.grey,
              )
            ),
            subtitle: Text("Código: ${offer.code}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: offer.isActive,
                  activeColor: AppColors.turquesaVivo,
                  onChanged: (val) => _cambiarEstadoOferta(offer.id, val),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.alertaRojo),
                  onPressed: () => _confirmarBorrado(offer.id),
                ),
              ],
            ),
          ),
          if (!offer.isActive)
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
}