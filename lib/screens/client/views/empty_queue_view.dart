import 'package:flutter/material.dart';
// Asegúrate de importar tus colores
import '../../../config/app_colors.dart'; 

class EmptyQueueView extends StatefulWidget {
  // Cambiamos a Future para poder esperar a que termine la operación
  final Future<void> Function() onJoin; 

  const EmptyQueueView({super.key, required this.onJoin});

  @override
  State<EmptyQueueView> createState() => _EmptyQueueViewState();
}

class _EmptyQueueViewState extends State<EmptyQueueView> {
  bool _isLoading = false;

  void _handleJoin() async {
    setState(() => _isLoading = true);
    try {
      await widget.onJoin(); // Ejecuta la lógica de backend
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al unirse: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blancoPuro,
      appBar: AppBar(
        title: const Text("Tap&Go", style: TextStyle(color: AppColors.azulProfundo)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.nfc_outlined, size: 100, color: AppColors.turquesaVivo), // Icono cambiado a algo más "tech"
              const SizedBox(height: 32),
              const Text(
                "No estás en ninguna cola",
                style: TextStyle(color: AppColors.azulMedianoche, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "Acerca tu móvil a una etiqueta NFC\npara obtener tu turno.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 48),
              
              // Botón con estado de carga
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azulProfundo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _handleJoin,
                  icon: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: Text(
                    _isLoading ? "OBTENIENDO TURNO..." : "SIMULAR ESCANEO NFC",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}