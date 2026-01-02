import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../config/app_colors.dart';
import '../../../services/queue_service.dart';

class ActiveQueueView extends StatefulWidget {
  final VoidCallback onLeave;
  final String queueId;
  final int myTicketNumber;

  const ActiveQueueView({
    super.key,
    required this.onLeave,
    required this.queueId,
    required this.myTicketNumber,
  });

  @override
  State<ActiveQueueView> createState() => _ActiveQueueViewState();
}

class _ActiveQueueViewState extends State<ActiveQueueView> {
  final QueueService _queueService = QueueService();
  
  // 1. Plugin de notificaciones
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // 2. Bandera para evitar spam de notificaciones (que solo suene una vez)
  bool _hasNotified = false;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  // Configuración inicial de las notificaciones
  Future<void> _initNotifications() async {
    // 1. Configuración Android
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/launcher_icon');
    
    // 2. Configuración iOS
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings, 
      iOS: iosSettings
    );

    await _notificationsPlugin.initialize(settings);

    // 3. SOLICITAR PERMISO EN ANDROID 13+
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
    await androidImplementation?.requestNotificationsPermission();
  }

  // Método para lanzar la notificación
  Future<void> _showAlertNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'queue_channel', // id del canal
      'Avisos de Turno', // nombre del canal
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    await _notificationsPlugin.show(
      0, 
      '¡Prepárate!', 
      'Solo queda 1 persona delante de ti. Acércate al mostrador.', 
      details
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _queueService.getQueueStream(widget.queueId),
      builder: (context, snapshot) {
        
        // Manejo de Errores y Carga
        if (snapshot.hasError) return _buildErrorView("Error: ${snapshot.error}");
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        var doc = snapshot.data!;
        if (!doc.exists) return _buildErrorView("Esta cola ya no existe.");

        // Calculamos métricas
        final metrics = _queueService.calculateMetrics(doc, widget.myTicketNumber);

        // ============================================================
        // LÓGICA DE NOTIFICACIÓN
        // ============================================================
        // Si hay exactamente 1 persona delante Y no hemos avisado antes
        if (metrics.peopleAhead == 1 && !_hasNotified) {
          // Disparamos la notificación fuera del ciclo de renderizado
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAlertNotification();
            if (mounted) {
              setState(() {
                _hasNotified = true; // Bloqueamos para no repetir
              });
            }
          });
        }
        // ============================================================

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
                          "#${widget.myTicketNumber}",
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
                            value: (widget.myTicketNumber > 0) ? metrics.currentServing / widget.myTicketNumber : 0,
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
                    onPressed: widget.onLeave,
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
      body: Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(msg, textAlign: TextAlign.center)))
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