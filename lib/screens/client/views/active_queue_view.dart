import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../config/app_colors.dart';
// Importa el servicio que creamos en el paso anterior
import '../../../services/queue_service.dart'; 

class ActiveQueueView extends StatelessWidget {
  final VoidCallback onLeave;
  final String queueId;       // Necesitamos saber qué cola mirar
  final int myTicketNumber;   // Necesitamos saber cuál es mi número

  const ActiveQueueView({
    super.key, 
    required this.onLeave, 
    required this.queueId, 
    required this.myTicketNumber
  });

  @override
  Widget build(BuildContext context) {
    // Usamos StreamBuilder para escuchar cambios en la base de datos EN VIVO
    return StreamBuilder<DocumentSnapshot>(
      stream: QueueService().getQueueStream(queueId),
      builder: (context, snapshot) {
        
        // 1. Estado de Carga
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. Extraer datos de Firebase
        var data = snapshot.data!;
        if (!data.exists) return const Scaffold(body: Center(child: Text("La cola se ha cerrado")));

        int currentServing = data['current_number'] ?? 0; // A quién atienden ahora
        int peopleAhead = myTicketNumber - currentServing; // Cuántos tengo delante
        
        // Lógica visual: Si ya me pasé o es mi turno
        bool isMyTurn = peopleAhead <= 0;
        // Calculamos tiempo estimado (ej: 2 mins por persona)
        int estimatedMin = peopleAhead > 0 ? peopleAhead * 2 : 0; 

        return Scaffold(
          backgroundColor: AppColors.grisHielo,
          appBar: AppBar(
            title: Text(isMyTurn ? "¡ES TU TURNO!" : "Tu Turno"),
            backgroundColor: isMyTurn ? AppColors.turquesaVivo : Colors.white,
            foregroundColor: isMyTurn ? Colors.white : AppColors.azulProfundo,
            elevation: 0,
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // --- TARJETA PRINCIPAL ---
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
                        
                        // Mostramos TU número
                        Text(
                          "#$myTicketNumber", 
                          style: const TextStyle(color: AppColors.azulProfundo, fontSize: 80, fontWeight: FontWeight.bold, height: 1)
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Estado dinámico
                        Chip(
                          label: Text(
                            isMyTurn ? "PASA AL MOSTRADOR" : "EN ESPERA",
                            style: TextStyle(color: isMyTurn ? Colors.white : AppColors.azulProfundo, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: isMyTurn ? AppColors.turquesaVivo : AppColors.aquaSuave,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Barra de progreso visual (simple)
                        if (!isMyTurn) ...[
                          Text("Atendiendo ahora al: #$currentServing", style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: currentServing / myTicketNumber, // Barra avanza según se acerca tu número
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
                  
                  // --- TARJETAS DE INFORMACIÓN (Solo si no es mi turno) ---
                  if (!isMyTurn)
                    Row(children: [
                      Expanded(child: _infoCard(peopleAhead.toString(), "Personas delante", Icons.groups)),
                      const SizedBox(width: 16),
                      Expanded(child: _infoCard("$estimatedMin min", "Tiempo estimado", Icons.timer)),
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