import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../config/app_colors.dart';
// Asegúrate de importar tu servicio
import '../../../services/queue_service.dart'; 

class AdminQueueControl extends StatelessWidget {
  const AdminQueueControl({super.key});

  // ID de la cola que gestiona este Admin (Hardcoded para la demo)
  final String queueId = 'tienda_01';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Cola"),
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
      // ESCUCHAMOS LA BASE DE DATOS EN VIVO
      body: StreamBuilder<DocumentSnapshot>(
        stream: QueueService().getQueueStream(queueId),
        builder: (context, snapshot) {
          
          // 1. Estado de Carga
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists) return const Center(child: Text("Cola no iniciada"));

          // 2. Extraer Datos
          var data = snapshot.data!;
          int current = data['current_number'] ?? 0;
          int lastIssued = data['last_issued_number'] ?? 0;
          
          // Calculamos cuántos hay esperando (Total tickets dados - Ticket actual)
          int waitingCount = (lastIssued - current);
          if (waitingCount < 0) waitingCount = 0; // Por seguridad

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
                    _stat("2m", "T. Medio"), // Dato simulado por ahora
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
                                "#$current", // Mostramos dato real
                                style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: AppColors.azulMedianoche)
                              ),
                              const SizedBox(height: 20),
                              
                              // BOTÓN: LLAMAR AL SIGUIENTE
                              SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.turquesaVivo),
                                  onPressed: () {
                                    // ACCIÓN: Avanzar cola en Firebase
                                    QueueService().callNext(queueId);
                                  },
                                  child: const Text("LLAMAR AL SIGUIENTE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              
                              const SizedBox(height: 10),
                              
                              // Botón No Presentado (Por ahora hace lo mismo, avanza)
                              OutlinedButton(
                                onPressed: () {
                                  QueueService().callNext(queueId);
                                  // Aquí podrías añadir lógica extra para marcarlo como "skipped" en el futuro
                                },
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
                        
                        // Lista de siguientes (Simulación visual basada en el actual)
                        const Align(alignment: Alignment.centerLeft, child: Text("Siguientes:", style: TextStyle(fontWeight: FontWeight.bold))),
                        if (waitingCount > 0) _next("#${current + 1}", "Prepárate"),
                        if (waitingCount > 1) _next("#${current + 2}", "En 4 min"),
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