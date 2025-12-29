import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../services/parking_service.dart';
import '../../common/qr_scanner_screen.dart';

class AdminParkingValidator extends StatefulWidget {
  const AdminParkingValidator({super.key});

  @override
  State<AdminParkingValidator> createState() => _AdminParkingValidatorState();
}

class _AdminParkingValidatorState extends State<AdminParkingValidator> {
  final ParkingService _parkingService = ParkingService();
  bool _isLoading = false;

  // Lógica delegada al servicio
  Future<void> _procesarTicket(String ticketId) async {
    setState(() => _isLoading = true);

    try {
      // 1. El servicio verifica seguridad y calcula precio
      final calculation = await _parkingService.verifyAndCalculateTicket(ticketId);

      if (mounted) {
        // 2. Si todo ok, mostramos el diálogo con los datos calculados
        _mostrarDialogoCobro(calculation);
      }

    } catch (e) {
      _mostrarError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmarCobro(String ticketId, double precio) async {
    try {
      Navigator.pop(context); // Cerrar diálogo primero
      setState(() => _isLoading = true);
      
      // 3. El servicio escribe en la base de datos
      await _parkingService.processPayment(ticketId, precio);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Ticket validado correctamente"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      _mostrarError("Error al cobrar: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI ---

  void _mostrarDialogoCobro(TicketCalculation data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Validar Salida", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car, size: 50, color: AppColors.azulProfundo),
            const SizedBox(height: 10),
            const Divider(),
            _infoRow("Tiempo:", data.formattedTime),
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
                  Text("${data.totalPrice.toStringAsFixed(2)} €", 
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
            // Llamamos al wrapper de confirmación
            onPressed: () => _confirmarCobro(data.ticketId, data.totalPrice),
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