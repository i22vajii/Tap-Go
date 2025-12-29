import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../config/app_colors.dart';
import '../../../services/queue_service.dart';

class ActiveQueueView extends StatelessWidget {
  final VoidCallback onLeave;
  final String queueId;       
  final int myTicketNumber;   
  
  // Instanciamos el servicio
  final QueueService _queueService = QueueService();

  ActiveQueueView({
    super.key, 
    required this.onLeave, 
    required this.queueId, 
    required this.myTicketNumber
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _queueService.getQueueStream(queueId),
      builder: (context, snapshot) {
        
        // 1. Manejo de Errores UI
        if (snapshot.hasError) {
          return _buildErrorView("Ocurrió un error: ${snapshot.error}");
        }

        // 2. Estado de Carga UI
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var doc = snapshot.data!;
        if (!doc.exists) return _buildErrorView("Esta cola ya no existe o ha sido cerrada.");

        // 3. DELEGAMOS LA LÓGICA AL SERVICIO
        // Le pasamos el documento sucio y nos devuelve los datos limpios
        final metrics = _queueService.calculateMetrics(doc, myTicketNumber);

        // 4. Renderizado UI puro
        return Scaffold(
          backgroundColor: AppColors.grisHielo,
          appBar: AppBar(
            title: Text(metrics.isMyTurn ? "¡ES TU TURNO!" : "Tu Turno"),
            backgroundColor: metrics.isMyTurn ? AppColors.turquesaVivo : Colors.white,
            foregroundColor: metrics.isMyTurn ? Colors.white : AppColors.azulProfundo,
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
                            metrics.isMyTurn ? "PASA AL MOSTRADOR" : "EN ESPERA",
                            style: TextStyle(color: metrics.isMyTurn ? Colors.white : AppColors.azulProfundo, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: metrics.isMyTurn ? AppColors.turquesaVivo : AppColors.aquaSuave,
                        ),
                        const SizedBox(height: 30),
                        
                        if (!metrics.isMyTurn) ...[
                          Text("Atendiendo ahora al: #${metrics.currentServing}", style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: (myTicketNumber > 0) ? metrics.currentServing / myTicketNumber : 0, 
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
                  
                  if (!metrics.isMyTurn)
                    Row(children: [
                      Expanded(child: _infoCard(metrics.peopleAhead.toString(), "Personas delante", Icons.groups)),
                      const SizedBox(width: 16),
                      Expanded(child: _infoCard(metrics.formattedWaitTime, "Tiempo estimado", Icons.timer)), 
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

  Widget _buildErrorView(String msg) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(msg, textAlign: TextAlign.center),
        )
      )
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