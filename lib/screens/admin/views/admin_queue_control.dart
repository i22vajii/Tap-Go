import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../config/app_colors.dart';

class AdminQueueControl extends StatefulWidget {
  const AdminQueueControl({super.key});

  @override
  State<AdminQueueControl> createState() => _AdminQueueControlState();
}

class _AdminQueueControlState extends State<AdminQueueControl> {
  String? _shopId; // El ID ya no es fijo, se carga dinámicamente
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarDatosDelLocal();
  }

  // 1. Obtener el ID de la tienda del dueño logueado
  Future<void> _cargarDatosDelLocal() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "No hay sesión activa";

      final doc = await FirebaseFirestore.instance.collection('owners').doc(user.uid).get();
      
      if (!doc.exists) {
        throw "Usuario no registrado como dueño en la BD";
      }

      setState(() {
        _shopId = doc.data()?['shopID']; // Ej: "cafeteria_central"
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // 2. Función para avanzar turno (Directa a Firebase)
  Future<void> _llamarSiguiente(int currentNumber) async {
    if (_shopId == null) return;
    
    // Solo actualizamos el número actual. 
    // El 'waitingCount' se calcula solo (total - actual).
    await FirebaseFirestore.instance.collection('queues').doc(_shopId).update({
      'current_number': currentNumber + 1,
    });
  }

  @override
  Widget build(BuildContext context) {
    // Estados de carga y error iniciales
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage != null) return Scaffold(body: Center(child: Text("Error: $_errorMessage")));
    if (_shopId == null) return const Scaffold(body: Center(child: Text("No tienes tienda asignada")));

    return Scaffold(
      appBar: AppBar(
        title: Text(" $_shopId"), // Mostramos el ID real
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Chip(
              label: Text("EN SERVICIO", style: TextStyle(color: AppColors.turquesaVivo, fontSize: 10, fontWeight: FontWeight.bold)),
              backgroundColor: AppColors.blancoPuro,
            ),
          )
        ],
      ),
      // ESCUCHAMOS LA COLA ESPECÍFICA DE ESTE LOCAL
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('queues').doc(_shopId).snapshots(),
        builder: (context, snapshot) {
          
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          // Si el documento de la cola no existe, damos opción a crearlo
          if (!snapshot.data!.exists) {
            return Center(
              child: ElevatedButton(
                onPressed: () {
                  FirebaseFirestore.instance.collection('queues').doc(_shopId).set({
                    'current_number': 0,
                    'last_issued_number': 0,
                  });
                }, 
                child: const Text("INICIAR SISTEMA DE COLA")
              ),
            );
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          
          // Usamos tus nombres de campos:
          int current = data['current_number'] ?? 0;
          int lastIssued = data['last_issued_number'] ?? 0;
          
          // Calculamos esperando
          int waitingCount = (lastIssued - current);
          if (waitingCount < 0) waitingCount = 0;

          return Column(
            children: [
              // --- BARRA DE ESTADÍSTICAS ---
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.azulProfundo,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(waitingCount.toString(), "Esperando"),
                    _stat("2m", "T. Medio"),
                    _stat(current.toString(), "Atendidos")
                  ],
                ),
              ),
              
              // --- ZONA PRINCIPAL ---
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text("TURNO ACTUAL", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        
                        // Tarjeta del turno gigante
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.blancoPuro,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]
                          ),
                          child: Column(
                            children: [
                              Text(
                                "#$current",
                                style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: AppColors.azulMedianoche)
                              ),
                              const SizedBox(height: 20),
                              
                              // BOTÓN: LLAMAR AL SIGUIENTE
                              SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.turquesaVivo),
                                  onPressed: () => _llamarSiguiente(current),
                                  child: const Text("LLAMAR AL SIGUIENTE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              
                              const SizedBox(height: 10),
                              
                              // Botón No Presentado
                              OutlinedButton(
                                onPressed: () => _llamarSiguiente(current), // Avanza igual
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.alertaRojo,
                                  side: const BorderSide(color: AppColors.alertaRojo)
                                ),
                                child: const Text("NO PRESENTADO"),
                              )
                            ]
                          )
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Lista de siguientes
                        const Align(alignment: Alignment.centerLeft, child: Text("Siguientes:", style: TextStyle(fontWeight: FontWeight.bold))),
                        if (waitingCount > 0) _next("#${current + 1}", "Prepárate"),
                        if (waitingCount > 1) _next("#${current + 2}", "En espera"),
                        if (waitingCount == 0) const Padding(padding: EdgeInsets.only(top:20), child: Text("No hay nadie más en la cola", style: TextStyle(color: Colors.grey))),
                      ]
                    )
                  )
                )
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _stat(String v, String l) => Column(children: [Text(v, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10))]);
  
  Widget _next(String t, String w) => ListTile(
    leading: CircleAvatar(backgroundColor: AppColors.grisHielo, child: Text(t, style: const TextStyle(color: AppColors.azulMedianoche, fontSize: 12))),
    title: const Text("Cliente en espera"),
    trailing: Text(w, style: const TextStyle(color: Colors.grey)),
  );
}