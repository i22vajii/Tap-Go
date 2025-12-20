import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart'; // 1. Importamos el paquete NFC
import '../../../config/app_colors.dart';
import 'dart:convert';

class EmptyQueueView extends StatefulWidget {
  final Future<void> Function() onJoin;

  const EmptyQueueView({super.key, required this.onJoin});

  @override
  State<EmptyQueueView> createState() => _EmptyQueueViewState();
}

class _EmptyQueueViewState extends State<EmptyQueueView> {
  bool _isLoading = false; // Cargando datos del backend
  bool _isScanning = false; // Buscando etiqueta NFC

  // Función para iniciar el escaneo (CORREGIDA FINAL)
  void _startNfcScan() async {
    // 1. Comprobar si el dispositivo soporta NFC
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      _showError("El NFC está desactivado o no disponible en este dispositivo.");
      return;
    }

    setState(() => _isScanning = true);

    try {
      // 2. Iniciar la sesión de escucha
      await NfcManager.instance.startSession(
        // --- AQUI ESTÁ EL CAMBIO IMPORTANTE ---
        // Le decimos que busque los tipos de etiquetas más comunes
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        // --------------------------------------
        
        onDiscovered: (NfcTag tag) async {
          try {
            // 1. Extraemos la información NDEF (el formato estándar de datos)
            Ndef? ndef = Ndef.from(tag);
  
            if (ndef == null || ndef.cachedMessage == null) {
              // La etiqueta está vacía o no es compatible
              throw "Etiqueta vacía o no compatible";
            }
  
            // 2. Leemos el primer registro (donde escribimos el texto)
            NdefRecord record = ndef.cachedMessage!.records.first;
  
            // Decodificamos el texto (los payloads de texto tienen una cabecera rara)
            // Saltamos el primer byte (idioma) y decodificamos el resto
            String payload = utf8.decode(record.payload.sublist(1)); // Necesitas import 'dart:convert';
  
            // A veces el payload trae el código de lenguaje 'en' al principio, lo limpiamos si hace falta
            // Una forma bruta pero efectiva para este ejemplo:
            String textoLeido = payload.substring(2); // Saltamos "en" (ej: enTAPGO...)
  
            print("ETIQUETA LEÍDA: $textoLeido"); // Para que lo veas en consola
  
            // 3. COMPROBACIÓN DE SEGURIDAD
            if (textoLeido.contains("TAPGO_TIENDA_01")) {
              // ¡ES NUESTRA ETIQUETA!
              await NfcManager.instance.stopSession();
              if (mounted) {
                setState(() => _isScanning = false);
                _handleJoin(); // Unirse a la cola
              }
            } else {
              // ES UNA ETIQUETA DESCONOCIDA (ej: Tarjeta del Bus)
              throw "Etiqueta no válida para Tap-Go";
            }
  
          } catch (e) {
            await NfcManager.instance.stopSession(); // Importante: stopSession sin msg en Android
            if (mounted) {
               setState(() => _isScanning = false);
               _showError("Error: $e");
            }
          }
        },      
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        _showError("Error al iniciar lector NFC: $e");
      }
    }
  }

  void _handleJoin() async {
    setState(() => _isLoading = true);
    try {
      await widget.onJoin(); // Llama a tu backend
    } catch (e) {
      _showError("Error al unirse: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.alertaRojo),
    );
  }

  // Importante: Cancelar el escaneo si salimos de la pantalla
  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determinamos el texto y el icono según el estado
    String buttonText = "ESCANEAR ETIQUETA NFC";
    IconData buttonIcon = Icons.nfc;
    Color buttonColor = AppColors.azulProfundo;

    if (_isScanning) {
      buttonText = "ACERCA EL MÓVIL...";
      buttonIcon = Icons.wifi_tethering; // Icono de ondas
      buttonColor = AppColors.turquesaVivo;
    } else if (_isLoading) {
      buttonText = "OBTENIENDO TURNO...";
    }

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
              // Animación visual si está escaneando
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isScanning 
                      ? AppColors.turquesaVivo.withOpacity(0.1) 
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.nfc_outlined,
                  size: 100,
                  color: _isScanning ? AppColors.turquesaVivo : AppColors.azulProfundo,
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                _isScanning ? "Buscando punto NFC..." : "No estás en ninguna cola",
                style: const TextStyle(
                    color: AppColors.azulMedianoche,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 12),
              
              const Text(
                "Acerca tu móvil a una etiqueta NFC\npara obtener tu turno.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              
              const SizedBox(height: 48),

              // Botón Principal
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  // Si está cargando no hace nada, si no escanea inicia escaneo, si escanea no hace nada
                  onPressed: (_isLoading || _isScanning) ? null : _startNfcScan,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Icon(buttonIcon, color: Colors.white),
                  label: Text(
                    buttonText,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              
              // Botón secundario para cancelar escaneo si se queda pillado
              if (_isScanning)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: TextButton(
                    onPressed: () async {
                      await NfcManager.instance.stopSession();
                      setState(() => _isScanning = false);
                    },
                    child: const Text("Cancelar escaneo", style: TextStyle(color: Colors.grey)),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}