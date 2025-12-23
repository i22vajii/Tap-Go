import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../config/app_colors.dart';
import 'dart:convert';

class EmptyQueueView extends StatefulWidget {
  final Future<void> Function(String queueId) onJoin;

  const EmptyQueueView({super.key, required this.onJoin});

  @override
  State<EmptyQueueView> createState() => _EmptyQueueViewState();
}

class _EmptyQueueViewState extends State<EmptyQueueView> {
  bool _isLoading = false;
  bool _isScanningNfc = false;

  // --- LÓGICA CENTRALIZADA DE VALIDACIÓN ---
  void _validateAndJoin(String codigoLeido) async {
    print('CÓDIGO PROCESADO: $codigoLeido');
    
    // Asumimos que el código leído es directamente el ID de la tienda (ej: "tienda_01")
    if (codigoLeido.isNotEmpty && codigoLeido.startsWith("tienda_")) {
      if (mounted) {
        setState(() => _isScanningNfc = false);
        _handleJoin(codigoLeido);
      }
    } else {
      _showError("El código no es válido. Debe ser un ID de tienda válido.");
    }
  }

  // --- LÓGICA NFC ---
  void _startNfcScan() async {
    NfcAvailability availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      _showError("El NFC está desactivado o no disponible.");
      return;
    }

    setState(() => _isScanningNfc = true);

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) throw 'No es un tag NDEF';
            
            final ndefMessage = ndef.cachedMessage;
            if (ndefMessage == null) throw 'Etiqueta vacía';

            final record = ndefMessage.records.first;
            final payload = List<int>.from(record.payload);
            String textoLeido = utf8.decode(payload.sublist(1));

            if (textoLeido.length > 2) {
              textoLeido = textoLeido.substring(2);
            }

            await NfcManager.instance.stopSession();
            _validateAndJoin(textoLeido);

          } catch (e) {
            await NfcManager.instance.stopSession();
            if (mounted) {
              setState(() => _isScanningNfc = false);
              _showError("Error leyendo etiqueta NFC.");
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isScanningNfc = false);
        _showError("Error al iniciar lector NFC: $e");
      }
    }
  }

  // --- LÓGICA QR (VISUAL MEJORADO) ---
  void _startQrScan() async {
    // Navegamos a la pantalla personalizada y esperamos el resultado
    final codigo = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const _QrScannerScreen()),
    );

    // Si volvimos con un código, lo validamos
    if (codigo != null && codigo is String) {
      _validateAndJoin(codigo);
    }
  }

  void _handleJoin(String queueId) async {
    setState(() => _isLoading = true);
    try {
      await widget.onJoin(queueId);
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

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String nfcButtonText = "ESCANEAR ETIQUETA NFC";
    IconData nfcButtonIcon = Icons.nfc;
    Color nfcButtonColor = AppColors.azulProfundo;

    if (_isScanningNfc) {
      nfcButtonText = "ACERCA EL MÓVIL...";
      nfcButtonIcon = Icons.wifi_tethering;
      nfcButtonColor = AppColors.turquesaVivo;
    } else if (_isLoading) {
      nfcButtonText = "OBTENIENDO TURNO...";
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
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isScanningNfc 
                      ? AppColors.turquesaVivo.withOpacity(0.1) 
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.nfc_outlined,
                  size: 100,
                  color: _isScanningNfc ? AppColors.turquesaVivo : AppColors.azulProfundo,
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                _isScanningNfc ? "Buscando punto NFC..." : "No estás en ninguna cola",
                style: const TextStyle(
                    color: AppColors.azulMedianoche,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 12),
              
              const Text(
                "Acerca tu móvil al punto NFC o escanea\nel código QR para obtener tu turno.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: nfcButtonColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: (_isLoading || _isScanningNfc) ? null : _startNfcScan,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Icon(nfcButtonIcon, color: Colors.white),
                  label: Text(
                    nfcButtonText,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (!_isLoading && !_isScanningNfc)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.azulProfundo, width: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _startQrScan,
                    icon: Icon(Icons.qr_code_scanner, color: AppColors.azulProfundo),
                    label: const Text(
                      "ESCANEAR CÓDIGO QR",
                      style: TextStyle(
                          color: AppColors.azulProfundo,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              
              if (_isScanningNfc)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: TextButton(
                    onPressed: () async {
                      await NfcManager.instance.stopSession();
                      setState(() => _isScanningNfc = false);
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

// ==========================================
// PANTALLA DE ESCÁNER (Clase Privada)
// ==========================================

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  bool _isScanned = false; 

  @override
  Widget build(BuildContext context) {
    final double scanWindowSize = 250.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Cámara
          MobileScanner(
            controller: controller,
            onDetect: (BarcodeCapture capture) {
              if (_isScanned) return; 
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _isScanned = true;
                  final String code = barcode.rawValue!;
                  Navigator.pop(context, code); // Devolvemos el código
                  break; 
                }
              }
            },
          ),

          // 2. Overlay Oscuro con hueco (Painter copiado de tu referencia)
          CustomPaint(
            painter: _ScannerOverlayPainter(
              scanWindow: Rect.fromCenter(
                center: MediaQuery.of(context).size.center(Offset.zero),
                width: scanWindowSize,
                height: scanWindowSize,
              ),
              borderRadius: 20.0,
            ),
            child: Container(),
          ),

          // 3. Interfaz UI (Botones y Texto)
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Botón cerrar
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      // Botón Linterna
                      IconButton(
                        icon: ValueListenableBuilder(
                          valueListenable: controller,
                          builder: (context, state, child) {
                            return Icon(
                              state.torchState == TorchState.off 
                                  ? Icons.flash_off 
                                  : Icons.flash_on,
                              color: Colors.white, 
                              size: 30
                            );
                          },
                        ),
                        onPressed: () => controller.toggleTorch(),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  "Enfoca el código QR de la tienda",
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)]
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          
          // 4. Borde decorativo turquesa (para que se vea bonito el hueco)
          Center(
            child: Container(
              width: scanWindowSize,
              height: scanWindowSize,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.turquesaVivo, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Pintor para el efecto de "recorte" oscuro
class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;

  _ScannerOverlayPainter({required this.scanWindow, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          scanWindow,
          Radius.circular(borderRadius),
        ),
      );

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Esta operación crea el "agujero"
    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(backgroundWithCutout, backgroundPaint);
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter oldDelegate) {
    return scanWindow != oldDelegate.scanWindow ||
        borderRadius != oldDelegate.borderRadius;
  }
}