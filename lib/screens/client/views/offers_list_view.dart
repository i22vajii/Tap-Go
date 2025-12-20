import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importante
import 'package:qr_flutter/qr_flutter.dart'; // Importante
import '../../../config/app_colors.dart';

class OffersListView extends StatelessWidget {
  const OffersListView({super.key});

  // Referencia a la misma colección que usa el Admin
  static final CollectionReference _ofertasRef =
      FirebaseFirestore.instance.collection('ofertas');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ofertas Disponibles")),
      body: StreamBuilder(
        // Escuchamos solo las ofertas que están marcadas como 'activa: true'
        stream: _ofertasRef.where('activa', isEqualTo: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error al cargar ofertas"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No hay ofertas disponibles en este momento."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

              return _offerTile(
                context,
                data['titulo'] ?? "Oferta",
                "Disponible ahora", // Puedes cambiar esto por un campo 'tienda' si lo añades a Firebase
                "CANJEAR", 
                Icons.local_offer,
                data['codigo'] ?? "", // Pasamos el código para el QR
              );
            },
          );
        },
      ),
    );
  }

  // Función para mostrar el QR al hacer clic
  void _mostrarQRCanje(BuildContext context, String titulo, String codigo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Canjear: $titulo", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enseña este código en el establecimiento"),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: codigo,
                version: QrVersions.auto,
                size: 200.0,
                gapless: false,
              ),
            ),
            const SizedBox(height: 10),
            Text(codigo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.azulProfundo)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          )
        ],
      ),
    );
  }

  Widget _offerTile(BuildContext context, String title, String store, String badge, IconData icon, String codigo) {
    return InkWell(
      onTap: () => _mostrarQRCanje(context, title, codigo), // Acción de pulsar
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.blancoPuro, 
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.aquaSuave,
                borderRadius: BorderRadius.circular(12)
              ),
              child: Icon(icon, color: AppColors.azulProfundo),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(store, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.turquesaVivo,
                borderRadius: BorderRadius.circular(8)
              ),
              child: Text(badge, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}