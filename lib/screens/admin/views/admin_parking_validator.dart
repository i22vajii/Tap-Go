import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import '../../../config/app_colors.dart';
import '../../common/qr_scanner_screen.dart';

class AdminParkingValidator extends StatefulWidget {
  const AdminParkingValidator({super.key});

  @override
  State<AdminParkingValidator> createState() => _AdminParkingValidatorState();
}

class _AdminParkingValidatorState extends State<AdminParkingValidator> {
  bool _isLoading = false;

  // Lógica para procesar el ticket escaneado
  Future<void> _procesarTicket(String ticketId) async {
    setState(() => _isLoading = true);

    try {
      // ---------------------------------------------------------
      // PASO 1: OBTENER DATOS DEL ADMINISTRADOR (SEGURIDAD)
      // ---------------------------------------------------------
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _mostrarError("No hay sesión de administrador activa.");
        return;
      }

      // Buscamos el perfil del admin para saber su shop_ID
      DocumentSnapshot adminDoc = await FirebaseFirestore.instance
          .collection('owners') 
          .doc(user.uid)
          .get();

      if (!adminDoc.exists) {
        _mostrarError("Error: No se encontró perfil de administrador.");
        return;
      }

      final adminData = adminDoc.data() as Map<String, dynamic>;
      final String adminShopId = adminData['shopID'] ?? 'sin_shop_id';

      // ---------------------------------------------------------
      // PASO 2: BUSCAR EL TICKET
      // ---------------------------------------------------------
      DocumentSnapshot ticketDoc = await FirebaseFirestore.instance
          .collection('tickets_parking')
          .doc(ticketId)
          .get();

      if (!ticketDoc.exists) {
        _mostrarError("Ticket no encontrado en la base de datos.");
        return;
      }

      Map<String, dynamic> ticketData = ticketDoc.data() as Map<String, dynamic>;

      // ---------------------------------------------------------
      // PASO 3: VALIDAR PROPIEDAD (SEGURIDAD)
      // ---------------------------------------------------------
      final String ticketShopId = ticketData['shopID'] ?? '';

      // AQUÍ ESTÁ LA RESTRICCIÓN:
      if (ticketShopId != adminShopId) {
        _mostrarError("⛔ ACCESO DENEGADO: Este ticket pertenece a otro parking.");
        return;
      }

      // ---------------------------------------------------------
      // PASO 4: VERIFICAR ESTADO Y CALCULAR
      // ---------------------------------------------------------
      
      // Verificar si ya está validado
      if (ticketData['estado'] == 'validado') {
        _mostrarError("Este ticket YA fue validado anteriormente.");
        return;
      }

      // Calcular Coste (Ejemplo: 0.05€ el minuto)
      Timestamp entrada = ticketData['entrada'];
      DateTime horaEntrada = entrada.toDate();
      Duration estancia = DateTime.now().difference(horaEntrada);
      
      // Coste mínimo 1€, precio minuto 0.05€
      double precio = (estancia.inMinutes * 0.05);
      if (precio < 1.0) precio = 1.0; 

      if (mounted) {
        // Mostrar diálogo de cobro
        _mostrarDialogoCobro(ticketId, estancia, precio);
      }

    } catch (e) {
      _mostrarError("Error al leer ticket: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarDialogoCobro(String id, Duration tiempo, double precio) {
    showDialog(
      context: context,
      barrierDismissible: false, // Obliga a elegir
      builder: (ctx) => AlertDialog(
        title: const Text("Validar Salida", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car, size: 50, color: AppColors.azulProfundo),
            const SizedBox(height: 10),
            const Divider(),
            _infoRow("Tiempo:", "${tiempo.inHours}h ${tiempo.inMinutes.remainder(60)}m"),
            _infoRow("Tarifa:", "0.05€ / min"),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.turquesaVivo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TOTAL A COBRAR:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("${precio.toStringAsFixed(2)} €", 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.turquesaVivo)),
                ],
              ),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.turquesaVivo),
            onPressed: () async {
              // VALIDAR EN FIREBASE
              await FirebaseFirestore.instance.collection('tickets_parking').doc(id).update({
                'estado': 'validado',
                'coste': precio,
                'salida': FieldValue.serverTimestamp(),
                'validado_por': FirebaseAuth.instance.currentUser?.uid, // Opcional: registrar quién cobró
              });
              
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Ticket validado correctamente"), backgroundColor: Colors.green)
                );
              }
            },
            child: const Text("COBRAR Y ABRIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.alertaRojo));
  }

  Widget _infoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(val, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Control de Parking")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner_rounded, size: 100, color: AppColors.azulProfundo.withOpacity(0.2)),
              const SizedBox(height: 30),
              const Text(
                "Escanear Ticket de Salida",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.azulProfundo),
              ),
              const SizedBox(height: 10),
              const Text(
                "Escanea el código QR del cliente para calcular el importe y validar la salida.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text("ABRIR ESCÁNER", style: TextStyle(fontSize: 18, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azulProfundo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    // Abrimos el escáner (Usando QrScannerScreen externa)
                    final ticketId = await Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const QrScannerScreen())
                    );

                    // Verificamos que sea un String válido
                    if (ticketId != null && ticketId is String) {
                      _procesarTicket(ticketId);
                    }
                  },
                ),
              ),
              
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: CircularProgressIndicator(),
                )
            ],
          ),
        ),
      ),
    );
  }
}