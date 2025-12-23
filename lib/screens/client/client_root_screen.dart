import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
// IMPORTANTE: Asegúrate de importar tu servicio
import '../../services/queue_service.dart'; 
import 'views/active_queue_view.dart';
import 'views/empty_queue_view.dart';
import 'views/offers_list_view.dart';
import 'views/parking_ticket_view.dart';

class ClientRootScreen extends StatefulWidget {
  const ClientRootScreen({super.key});

  @override
  State<ClientRootScreen> createState() => _ClientRootScreenState();
}

class _ClientRootScreenState extends State<ClientRootScreen> {
  int _currentIndex = 0;

  // CAMBIO 1: En lugar de solo 'bool _isInQueue', guardamos los datos reales
  String? _currentQueueId; 
  int? _myTicketNumber;

  // Propiedad calculada para saber si estamos en cola (si hay ID, estamos en cola)
  bool get _isInQueue => _currentQueueId != null && _myTicketNumber != null;

  // CAMBIO 2: La función ahora acepta el queueId como parámetro
  Future<void> _joinQueue(String queueId) async {
    try {
      String userId = 'usuario_demo_1'; // ID temporal

      // Llamamos a Firebase con el queueId proporcionado
      int ticket = await QueueService().joinQueue(queueId, userId);

      // Actualizamos la pantalla con los datos recibidos
      setState(() {
        _currentQueueId = queueId;
        _myTicketNumber = ticket;
      });

    } catch (e) {
      // Si falla, mostramos un error (puedes mejorar esto luego)
      print("Error al unirse a la cola: $e");
      rethrow; // Lanzamos el error para que la vista muestre el mensaje rojo si tiene lógica para ello
    }
  }

  void _leaveQueue() {
    setState(() {
      _currentQueueId = null;
      _myTicketNumber = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Definimos las vistas
    final List<Widget> pages = [
      // CAMBIO 3: Pasamos los parámetros que faltaban
      _isInQueue
          ? ActiveQueueView(
              onLeave: _leaveQueue,
              queueId: _currentQueueId!,     // Pasamos el ID de la cola
              myTicketNumber: _myTicketNumber!, // Pasamos mi número
            )
          : EmptyQueueView(
              onJoin: _joinQueue // Ahora esta función es compatible (es Future)
            ),
      const OffersListView(),
      const ParkingTicketView(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.turquesaVivo,
        unselectedItemColor: AppColors.azulProfundo.withOpacity(0.4),
        backgroundColor: AppColors.blancoPuro,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Cola'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer_rounded), label: 'Ofertas'),
          BottomNavigationBarItem(icon: Icon(Icons.local_parking_rounded), label: 'Parking'),
        ],
      ),
    );
  }
}