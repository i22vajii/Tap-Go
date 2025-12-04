
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

class ActiveQueueView extends StatelessWidget {
  final VoidCallback onLeave;
  const ActiveQueueView({super.key, required this.onLeave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tu Turno")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: AppColors.blancoPuro, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)]),
                child: Column(
                  children: [
                    const Text("TU NÚMERO", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text("A-45", style: TextStyle(color: AppColors.turquesaVivo, fontSize: 80, fontWeight: FontWeight.bold, height: 1)),
                    const SizedBox(height: 10),
                    const Chip(label: Text("En espera"), backgroundColor: AppColors.aquaSuave),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(value: 0.7, backgroundColor: AppColors.grisHielo, valueColor: const AlwaysStoppedAnimation(AppColors.turquesaVivo)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _infoCard("5", "Delante", Icons.groups)),
                const SizedBox(width: 16),
                Expanded(child: _infoCard("10 min", "Estimado", Icons.timer)),
              ]),
              const SizedBox(height: 40),
              TextButton(onPressed: onLeave, child: const Text("Abandonar cola", style: TextStyle(color: AppColors.alertaRojo)))
            ],
          ),
        ),
      ),
    );
  }
  Widget _infoCard(String val, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.blancoPuro, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [Icon(icon, color: AppColors.azulProfundo), const SizedBox(height: 8), Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: Colors.grey))]),
    );
  }
}
