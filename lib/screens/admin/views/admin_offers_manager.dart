import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
// Asegúrate de que la ruta a tus colores sea correcta
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

  // --- LÓGICA DE FIREBASE ---

  // 1. Guardar nueva oferta
  Future<void> _subirOferta(String titulo, String codigo, bool activa) async {
    await _ofertasRef.add({
      'titulo': titulo,
      'codigo': codigo,
      'activa': activa, // Estado inicial (Visible/Oculta)
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 2. Cambiar visibilidad (Interruptor rápido)
  Future<void> _cambiarEstadoOferta(String id, bool nuevoEstado) async {
    await _ofertasRef.doc(id).update({'activa': nuevoEstado});
  }

  // 3. Diálogo de creación
  void _mostrarDialogoNuevaOferta() {
    String nuevoTitulo = "";
    String nuevoCodigo = "";
    bool estaActiva = false; // Por defecto nace oculta (Borrador)

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder necesario para que el Switch cambie visualmente dentro del Dialog
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Nueva Oferta"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Nombre (ej: Cafe 2x1)",
                      prefixIcon: Icon(Icons.abc),
                    ),
                    onChanged: (val) => nuevoTitulo = val,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Código QR (ej: CAFE2X1)",
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                    onChanged: (val) => nuevoCodigo = val,
                  ),
                  const SizedBox(height: 20),
                  // Interruptor de estado inicial
                  SwitchListTile(
                    title: Text(
                      estaActiva ? "Visible al público" : "Guardar como Borrador",
                      style: TextStyle(
                        color: estaActiva ? AppColors.turquesaVivo : Colors.grey,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    value: estaActiva,
                    activeColor: AppColors.turquesaVivo,
                    onChanged: (val) {
                      setState(() => estaActiva = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("Cancelar")
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.turquesaVivo),
                  onPressed: () {
                    if (nuevoTitulo.isNotEmpty && nuevoCodigo.isNotEmpty) {
                      _subirOferta(nuevoTitulo, nuevoCodigo, estaActiva);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Guardar", style: TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }

  // --- INTERFAZ DE USUARIO ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión Ofertas"),
        actions: [
          // Botón Escáner para validar cupones de clientes
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: "Validar Cupón",
            onPressed: () async {
              // Navegamos al escáner y esperamos el resultado
              final codigoLeido = await Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const ScannerScreen())
              );

              // Si volvió con un código
              if (codigoLeido != null) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("¡Cupón validado!: $codigoLeido"),
                    backgroundColor: AppColors.turquesaVivo,
                    behavior: SnackBarBehavior.floating,
                  )
                );
              }
            },
          )
        ],
      ),
      
      // Botón flotante para crear
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoNuevaOferta,
        backgroundColor: AppColors.turquesaVivo,
        label: const Text("NUEVA OFERTA", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
      
      // Lista en tiempo real
      body: StreamBuilder(
        stream: _ofertasRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error al cargar datos"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_offer_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No hay ofertas creadas", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
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

  // Tarjeta individual de oferta
  Widget _offerItem(String id, Map<String, dynamic> data) {
    bool activa = data['activa'] ?? false; // Si falta el campo, asumimos false

    return Card(
      elevation: activa ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: activa ? Colors.white : Colors.grey[100], // Gris si está inactiva
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: activa ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => _verQR(data['titulo'], data['codigo']),
            leading: CircleAvatar(
              backgroundColor: activa ? AppColors.aquaSuave : Colors.grey[300],
              child: Icon(
                Icons.local_offer, 
                color: activa ? AppColors.azulProfundo : Colors.grey
              ),
            ),
            title: Text(
              data['titulo'], 
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: activa ? null : TextDecoration.lineThrough, // Tachado si inactiva
                color: activa ? AppColors.azulMedianoche : Colors.grey,
              )
            ),
            subtitle: Text("Código: ${data['codigo']}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Interruptor ON/OFF
                Switch(
                  value: activa,
                  activeColor: AppColors.turquesaVivo,
                  onChanged: (val) => _cambiarEstadoOferta(id, val),
                ),
                // Botón Borrar
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.alertaRojo),
                  onPressed: () => _confirmarBorrado(id),
                ),
              ],
            ),
          ),
          
          // Barra inferior indicadora si es borrador
          if (!activa)
             Container(
               width: double.infinity,
               decoration: BoxDecoration(
                 color: Colors.grey[300],
                 borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))
               ),
               padding: const EdgeInsets.symmetric(vertical: 4),
               child: const Text(
                 "BORRADOR (OCULTO)", 
                 textAlign: TextAlign.center, 
                 style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)
               ),
             )
        ],
      ),
    );
  }

  // Diálogo de confirmación para borrar
  void _confirmarBorrado(String id) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar oferta?"),
        content: const Text("Esta acción no se puede deshacer y los códigos QR dejarán de funcionar."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              _ofertasRef.doc(id).delete();
              Navigator.pop(ctx);
            }, 
            child: const Text("Eliminar", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }

  // Ver QR generado (Para imprimirlo y pegarlo en la tienda)
  void _verQR(String titulo, String codigo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(20),
        title: Text("QR: $titulo", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200, 
              height: 200, 
              child: QrImageView(data: codigo, size: 200)
            ),
            const SizedBox(height: 10),
            Text(codigo, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar")),
        ],
      ),
    );
  }
}

// ==========================================
// PANTALLA DE ESCÁNER (CON VIEWFINER/CUADRADITO)
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
                  // Vibración (opcional)
                  // HapticFeedback.mediumImpact(); 
                  Navigator.pop(context, code); 
                  break; 
                }
              }
            },
          ),

          // 2. Overlay Oscuro
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

          // 3. Interfaz
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
                  "Enfoca el código QR del cliente",
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
          
          // 4. Borde decorativo
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

// Pintor para el efecto de "recorte"
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