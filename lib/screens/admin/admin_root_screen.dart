import 'package:flutter/material.dart';
import 'views/admin_queue_control.dart';
import 'views/admin_offers_manager.dart';
import 'views/admin_stats.dart';
import 'views/admin_parking_validator.dart'; // 1. IMPORTA EL NUEVO ARCHIVO
import '../../config/app_colors.dart';

class AdminRootScreen extends StatefulWidget {
  const AdminRootScreen({super.key});
  @override
  State<AdminRootScreen> createState() => _AdminRootScreenState();
}

class _AdminRootScreenState extends State<AdminRootScreen> {
  int _currentIndex = 0;

  final List<Widget> _adminPages = [
    const AdminQueueControl(),
    const AdminOffersManager(),
    const AdminParkingValidator(), // 2. AÑADIMOS LA PANTALLA AQUÍ
    const AdminStatistics(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _adminPages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.azulProfundo,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // Importante para >3 iconos
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dvr), 
            label: 'Cola'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_offer), 
            label: 'Ofertas'
          ),
          // 3. NUEVO BOTÓN PARKING
          BottomNavigationBarItem(
            icon: Icon(Icons.local_parking_rounded), 
            label: 'Parking'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart), 
            label: 'Stats'
          ),
        ],
      ),
    );
  }
}