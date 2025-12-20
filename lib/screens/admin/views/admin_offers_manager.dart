import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      'createdAt': FieldValue.serverTimestamp(),
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
        title: const Text("Gestión Ofertas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: "Validar Cupón",
            onPressed: () async {
              final codigoLeido = await Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const ScannerScreen())
              );

              if (codigoLeido != null) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Código validado: $codigoLeido"),
                    backgroundColor: AppColors.turquesaVivo,
                  )
                );
              }
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoNuevaOferta,
        backgroundColor: AppColors.turquesaVivo,
        label: const Text("NUEVA OFERTA", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.cloud_upload, color: Colors.white),
      ),
      body: StreamBuilder(
        stream: _ofertasRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error de conexión"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No hay ofertas activas"));
          }

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
          onPressed: () => _ofertasRef.doc(id).delete(),
        ),
      ),
    );
  }

  void _verQR(String titulo, String codigo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("QR de $titulo"),
        content: SizedBox(
          width: 200, 
          height: 200, 
          child: QrImageView(data: codigo, size: 200)
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA DE ESCÁNER (CORREGIDA V5.2.3)
// ==========================================

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
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
          // 1. CÁMARA
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

          // 2. RECUBRIMIENTO OSCURO (OVERLAY)
          CustomPaint(
            painter: ScannerOverlayPainter(
              scanWindow: Rect.fromCenter(
                center: MediaQuery.of(context).size.center(Offset.zero),
                width: scanWindowSize,
                height: scanWindowSize,
              ),
              borderRadius: 20.0,
            ),
            child: Container(),
          ),

          // 3. INTERFAZ (BOTONES Y TEXTO)
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      // --- BOTÓN LINTERNA CORREGIDO ---
                      // Ahora usamos ValueListenableBuilder escuchando al propio controller
                      IconButton(
                        icon: ValueListenableBuilder(
                          valueListenable: controller,
                          builder: (context, state, child) {
                            // En MobileScannerState 5.x, torchState es una propiedad directa
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
                      // --------------------------------
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  "Enfoca el código QR",
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
          
          // 4. BORDE DECORATIVO TURQUESA
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

// PINTOR DEL AGUJERO (MÁSCARA)
class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;

  ScannerOverlayPainter({required this.scanWindow, required this.borderRadius});

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

    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(backgroundWithCutout, backgroundPaint);
  }

  @override
  bool shouldRepaint(ScannerOverlayPainter oldDelegate) {
    return scanWindow != oldDelegate.scanWindow ||
        borderRadius != oldDelegate.borderRadius;
  }
}