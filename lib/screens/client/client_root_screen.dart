
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
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
 
  // Estado para simular si el usuario ya escaneó o no
  bool _isInQueue = false;

  void _joinQueue() {
    setState(() => _isInQueue = true);
  }

  void _leaveQueue() {
    setState(() => _isInQueue = false);
  }

  @override
  Widget build(BuildContext context) {
    // Definimos las vistas aquí para poder pasar funciones (callbacks)
    final List<Widget> pages = [
      _isInQueue
          ? ActiveQueueView(onLeave: _leaveQueue) // Vista con Turno
          : EmptyQueueView(onJoin: _joinQueue),   // Vista sin Turno
      const OffersListView(),
      const ParkingTicketView(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
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
