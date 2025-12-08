
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

class ParkingTicketView extends StatelessWidget {
  const ParkingTicketView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mi Parking")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(color: AppColors.blancoPuro, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: AppColors.azulProfundo, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    // Se ha eliminado 'const' antes de Column
                    child: Column(children: const [Icon(Icons.local_parking, color: Colors.white, size: 32), Text("Centro Comercial", style: TextStyle(color: Colors.white))])
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    // Se ha eliminado 'const' antes de Column
                    child: Column(children: [
                      const Icon(Icons.qr_code_2, size: 120),
                      const Text("Escanea para salir"),
                      const Divider(height: 40),
                      _row("Matrícula", "1234 KLM"),
                      const SizedBox(height: 10),
                      _row("Tiempo", "2h 15m"),
                      const Divider(height: 40),
                      // Se ha eliminado 'const' antes de Row
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Total:", style: TextStyle(fontWeight: FontWeight.bold)), Text("4,50 €", style: TextStyle(color: AppColors.turquesaVivo, fontSize: 24, fontWeight: FontWeight.bold))])
                    ])
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.nfc), label: const Text("PAGAR CON NFC"))),
          ],
        ),
      ),
    );
  }
  Widget _row(String k, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(k, style: const TextStyle(color: Colors.grey)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]);
}
