import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importante
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../config/app_colors.dart';

class AdminOffersManager extends StatefulWidget {
  const AdminOffersManager({super.key});

  @override
  State<AdminOffersManager> createState() => _AdminOffersManagerState();
}

class _AdminOffersManagerState extends State<AdminOffersManager> {
  // Referencia a la colección de Firebase
  final CollectionReference _ofertasRef = 
      FirebaseFirestore.instance.collection('ofertas');

  // Función para guardar en Firebase
  Future<void> _subirOferta(String titulo, String codigo) async {
    await _ofertasRef.add({
      'titulo': titulo,
      'codigo': codigo,
      'activa': true,
      'createdAt': FieldValue.serverTimestamp(), // Para ordenar por fecha
    });
  }

  void _mostrarDialogoNuevaOferta() {
    String nuevoTitulo = "";
    String nuevoCodigo = "";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nueva Oferta"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: "Nombre (ej: Cafe 2x1)"),
              onChanged: (val) => nuevoTitulo = val,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Código QR (ej: CAFE2X1)"),
              onChanged: (val) => nuevoCodigo = val,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.turquesaVivo),
            onPressed: () {
              if (nuevoTitulo.isNotEmpty && nuevoCodigo.isNotEmpty) {
                _subirOferta(nuevoTitulo, nuevoCodigo);
                Navigator.pop(context);
              }
            },
            child: const Text("Guardar en Nube", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión Ofertas del Administrador"),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen())),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoNuevaOferta,
        backgroundColor: AppColors.turquesaVivo,
        label: const Text("NUEVA OFERTA"),
        icon: const Icon(Icons.cloud_upload),
      ),
      // Escuchando cambios en tiempo real desde Firebase
      body: StreamBuilder(
        stream: _ofertasRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error de conexión"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          return ListView(
            padding: const EdgeInsets.all(20),
            children: snapshot.data!.docs.map((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              return _offerItem(doc.id, data);
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _offerItem(String id, Map<String, dynamic> data) {
    bool activa = data['activa'] ?? true;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => _verQR(data['titulo'], data['codigo']),
        leading: Icon(Icons.local_offer, color: activa ? AppColors.azulProfundo : Colors.grey),
        title: Text(data['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Código: ${data['codigo']}"),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.alertaRojo),
          onPressed: () => _ofertasRef.doc(id).delete(), // Borra de Firebase
        ),
      ),
    );
  }

  void _verQR(String titulo, String codigo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("QR de $titulo"),
        content: SizedBox(width: 200, height: 200, child: QrImageView(data: codigo, size: 200)),
      ),
    );
  }
}

// (La clase ScannerScreen se mantiene igual que en el ejemplo anterior)
class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Validar QR")),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            final String code = barcode.rawValue ?? "";
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Código Escaneado: $code")));
            Navigator.pop(context);
            break;
          }
        },
      ),
    );
  }
}