import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 1. IMPORTAR AUTH
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../../config/app_colors.dart';

class ParkingTicketView extends StatefulWidget {
  const ParkingTicketView({super.key});

  @override
  State<ParkingTicketView> createState() => _ParkingTicketViewState();
}

class _ParkingTicketViewState extends State<ParkingTicketView> {
  String? _currentTicketId;

  // --- LÓGICA DE BASE DE DATOS ---
  
  Future<void> _simularEntradaParking() async {
    try {
      // 2. OBTENER EL USUARIO REAL AUTOMÁTICAMENTE
      User? usuarioActual = FirebaseAuth.instance.currentUser;
      
      // Si no hay usuario logueado (raro si ya entraste a la app), usamos "anonimo"
      String uid = usuarioActual?.uid ?? 'usuario_invitado';

      DocumentReference ref = await FirebaseFirestore.instance.collection('tickets_parking').add({
        'matricula': '1234 KLM',
        'entrada': FieldValue.serverTimestamp(),
        'estado': 'pendiente',
        'coste': 0.0,
        'usuario_uid': uid, // 3. AHORA SE GUARDA EL ID REAL
      });

      setState(() {
        _currentTicketId = ref.id;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
    }
  }

  // 2. Simular Salida: Resetea la pantalla
  void _salirDelParking() {
    setState(() {
      _currentTicketId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mi Parking")),
      backgroundColor: AppColors.grisHielo,
      body: _currentTicketId == null 
          ? _buildEntradaView() 
          : _buildTicketActivoView(),
    );
  }

  // --- VISTA A: SIN TICKET (Botón para entrar) ---
  Widget _buildEntradaView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_parking_rounded, size: 100, color: AppColors.azulProfundo.withOpacity(0.5)),
            const SizedBox(height: 20),
            const Text(
              "Bienvenido al Parking",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.azulMedianoche),
            ),
            const SizedBox(height: 10),
            const Text(
              "Pulsa el botón para simular que escaneas el NFC de la barrera de entrada.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.nfc, color: Colors.white),
                label: const Text("SIMULAR ENTRADA NFC", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.turquesaVivo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _simularEntradaParking,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- VISTA B: TICKET ACTIVO (Escuchando cambios en tiempo real) ---
  Widget _buildTicketActivoView() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('tickets_parking').doc(_currentTicketId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error al cargar ticket"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        if (!snapshot.data!.exists) {
          return const Center(child: Text("El ticket ha sido eliminado"));
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        
        Timestamp entrada = data['entrada'] ?? Timestamp.now();
        DateTime fechaEntrada = entrada.toDate();
        Duration tiempo = DateTime.now().difference(fechaEntrada);
        String tiempoTexto = "${tiempo.inHours}h ${tiempo.inMinutes.remainder(60)}m";
        
        String estado = data['estado'] ?? 'pendiente';
        bool isValidado = estado == 'validado';

        return SingleChildScrollView(
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
                      decoration: BoxDecoration(
                        color: isValidado ? Colors.green : AppColors.azulProfundo, 
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          Icon(isValidado ? Icons.check_circle : Icons.local_parking, color: Colors.white, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            isValidado ? "TICKET VALIDADO" : "TICKET ACTIVO",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            isValidado ? "Puedes salir del parking" : "Pendiente de pago/validación",
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          )
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 180,
                            width: 180,
                            child: QrImageView(
                              data: _currentTicketId ?? "error", 
                              version: QrVersions.auto,
                              size: 200.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isValidado ? "¡Buen viaje!" : "Muestra este QR al salir", 
                            style: const TextStyle(fontSize: 12, color: Colors.grey)
                          ),
                          
                          const Divider(height: 40),
                          
                          _row("Matrícula", data['matricula'] ?? "---"),
                          const SizedBox(height: 10),
                          _row("Hora Entrada", DateFormat('HH:mm').format(fechaEntrada)),
                          const SizedBox(height: 10),
                          _row("Tiempo aprox.", tiempoTexto),
                          
                          const Divider(height: 40),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Estado:", style: TextStyle(fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isValidado ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20)
                                ),
                                child: Text(
                                  estado.toUpperCase(),
                                  style: TextStyle(
                                    color: isValidado ? Colors.green : Colors.orange,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              if (isValidado) 
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _salirDelParking,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulProfundo),
                    child: const Text("SALIR DEL PARKING", style: TextStyle(color: Colors.white)),
                  ),
                )
              else
                TextButton(
                  onPressed: _salirDelParking,
                  child: const Text("Cancelar Demo (Reset)", style: TextStyle(color: Colors.grey)),
                )
            ],
          ),
        );
      },
    );
  }

  Widget _row(String k, String v) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
    children: [
      Text(k, style: const TextStyle(color: Colors.grey)), 
      Text(v, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.azulMedianoche))
    ]
  );
}