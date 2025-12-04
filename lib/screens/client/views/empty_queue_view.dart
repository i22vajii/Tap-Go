
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

class EmptyQueueView extends StatelessWidget {
  final VoidCallback onJoin;
  const EmptyQueueView({super.key, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tap&Go")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_accounts_outlined, size: 80, color: AppColors.aquaSuave),
              const SizedBox(height: 32),
              const Text("No estás en ninguna cola", style: TextStyle(color: AppColors.azulMedianoche, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text("Escanea un NFC o QR para empezar.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.azulProfundo, fontSize: 16)),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: onJoin, // Simula el escaneo
                  icon: const Icon(Icons.nfc),
                  label: const Text("SIMULAR ESCANEO NFC"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
