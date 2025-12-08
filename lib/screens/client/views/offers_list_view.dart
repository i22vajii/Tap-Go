
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

class OffersListView extends StatelessWidget {
  const OffersListView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ofertas")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _offerTile("2x1 Cafés", "Cafetería Central", "-50%", Icons.coffee),
          const SizedBox(height: 16),
          _offerTile("15% Zapatillas", "Sport Shop", "-15%", Icons.directions_run),
          const SizedBox(height: 16),
          _offerTile("Postre Gratis", "Restaurante", "FREE", Icons.restaurant),
        ],
      ),
    );
  }
  Widget _offerTile(String title, String store, String badge, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.blancoPuro, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(width: 60, height: 60, decoration: BoxDecoration(color: AppColors.aquaSuave, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.azulProfundo)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(store, style: const TextStyle(color: Colors.grey))])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppColors.turquesaVivo, borderRadius: BorderRadius.circular(8)), child: Text(badge, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
