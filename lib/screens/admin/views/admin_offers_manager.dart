
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

class AdminOffersManager extends StatelessWidget {
  const AdminOffersManager({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Ofertas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: "Escanear Oferta",
            onPressed: () {},
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: (){}, backgroundColor: AppColors.turquesaVivo, label: const Text("NUEVA OFERTA"), icon: const Icon(Icons.add)),
      body: ListView(padding: const EdgeInsets.all(20), children: [_offerItem("2x1 Desayuno", "CODE24", true), _offerItem("10% Nuevos", "HOLA10", true), _offerItem("Cena Gratis", "FREE", false)]),
    );
  }
  Widget _offerItem(String title, String code, bool active) => Card(margin: const EdgeInsets.only(bottom: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: ListTile(leading: Icon(Icons.local_offer, color: active ? AppColors.azulProfundo : Colors.grey), title: Text(title, style: TextStyle(color: active ? Colors.black : Colors.grey)), subtitle: Text(code), trailing: const Icon(Icons.delete_outline, color: AppColors.alertaRojo)));
}
