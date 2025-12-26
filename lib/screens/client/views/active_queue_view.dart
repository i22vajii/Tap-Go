import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../config/app_colors.dart';
import '../../../services/queue_service.dart'; 

class ActiveQueueView extends StatelessWidget {
  final VoidCallback onLeave;
  final String queueId;       
  final int myTicketNumber;   

  const ActiveQueueView({
    super.key, 
    required this.onLeave, 
    required this.queueId, 
    required this.myTicketNumber
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: QueueService().getQueueStream(queueId),
      builder: (context, snapshot) {
        
        // 1. MANEJO DE ERRORES
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text("Ocurrió un error: ${snapshot.error}", textAlign: TextAlign.center),
              )
            )
          );
        }

        // 2. Estado de Carga
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 3. Validación de Documento
        var doc = snapshot.data!;
        if (!doc.exists) return const Scaffold(body: Center(child: Text("Esta cola ya no existe o ha sido cerrada.")));

        // 4. EXTRACCIÓN SEGURA DE DATOS
        final data = doc.data() as Map<String, dynamic>? ?? {};

        int safeInt(dynamic val) => (val is num) ? val.toInt() : int.tryParse(val.toString()) ?? 0;
        num safeNum(dynamic val) => (val is num) ? val : num.tryParse(val.toString()) ?? 0;

        int currentServing = safeInt(data['current_number']);
        int peopleAhead = myTicketNumber - currentServing;
        bool isMyTurn = peopleAhead <= 0;

        // --- CÁLCULO DE TIEMPO (MODIFICADO) ---
        String formattedTime = "0 min"; // Valor por defecto
        
        if (peopleAhead > 0) {
          num totalServiceSeconds = safeNum(data['total_service_seconds']);
          int servedCounts = safeInt(data['served_count']);

          double avgSecondsPerPerson;

          if (servedCounts > 0) {
            avgSecondsPerPerson = (totalServiceSeconds / servedCounts).toDouble();
          } else {
            avgSecondsPerPerson = 120.0; // 2 min por defecto
          }

          double totalSecondsWait = peopleAhead * avgSecondsPerPerson;
          
          int minutes = totalSecondsWait ~/ 60; // División entera para minutos
          int seconds = (totalSecondsWait % 60).toInt(); // Resto para segundos
          
          // Formateamos: si hay 0 minutos, solo muestra segundos, si no, ambos.
          if (minutes > 0) {
            formattedTime = "$minutes min $seconds s";
          } else {
            formattedTime = "$seconds s";
          }
        }
        // ------------------------

        return Scaffold(
          backgroundColor: AppColors.grisHielo,
          appBar: AppBar(
            title: Text(isMyTurn ? "¡ES TU TURNO!" : "Tu Turno"),
            backgroundColor: isMyTurn ? AppColors.turquesaVivo : Colors.white,
            foregroundColor: isMyTurn ? Colors.white : AppColors.azulProfundo,
            elevation: 0,
            automaticallyImplyLeading: false, 
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // TARJETA DE TURNO
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.blancoPuro, 
                      borderRadius: BorderRadius.circular(24), 
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))]
                    ),
                    child: Column(
                      children: [
                        const Text("TU NÚMERO", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const SizedBox(height: 10),
                        Text(
                          "#$myTicketNumber", 
                          style: const TextStyle(color: AppColors.azulProfundo, fontSize: 80, fontWeight: FontWeight.bold, height: 1)
                        ),
                        const SizedBox(height: 20),
                        Chip(
                          label: Text(
                            isMyTurn ? "PASA AL MOSTRADOR" : "EN ESPERA",
                            style: TextStyle(color: isMyTurn ? Colors.white : AppColors.azulProfundo, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: isMyTurn ? AppColors.turquesaVivo : AppColors.aquaSuave,
                        ),
                        const SizedBox(height: 30),
                        
                        if (!isMyTurn) ...[
                          Text("Atendiendo ahora al: #$currentServing", style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: (myTicketNumber > 0) ? currentServing / myTicketNumber : 0, 
                            backgroundColor: AppColors.grisHielo, 
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                            valueColor: const AlwaysStoppedAnimation(AppColors.turquesaVivo)
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  if (!isMyTurn)
                    Row(children: [
                      Expanded(child: _infoCard(peopleAhead.toString(), "Personas delante", Icons.groups)),
                      const SizedBox(width: 16),
                      // Usamos la nueva variable formattedTime
                      Expanded(child: _infoCard(formattedTime, "Tiempo estimado", Icons.timer)), 
                    ]),

                  const SizedBox(height: 40),
                  TextButton(
                    onPressed: onLeave, 
                    child: const Text("Abandonar cola", style: TextStyle(color: AppColors.alertaRojo, fontSize: 16))
                  )
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _infoCard(String val, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(color: AppColors.blancoPuro, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Icon(icon, color: AppColors.turquesaVivo, size: 28), 
          const SizedBox(height: 12), 
          Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.azulMedianoche)), 
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))
        ]
      ),
    );
  }
}