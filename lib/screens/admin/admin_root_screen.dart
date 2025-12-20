import 'package:flutter/material.dart';
import 'views/admin_queue_control.dart';
import 'views/admin_offers_manager.dart';
import 'views/admin_stats.dart'; // Asegúrate de crear este archivo
import '../../config/app_colors.dart';

class AdminRootScreen extends StatefulWidget {
  const AdminRootScreen({super.key});
  @override
  State<AdminRootScreen> createState() => _AdminRootScreenState();
}

class _AdminRootScreenState extends State<AdminRootScreen> {
  int _currentIndex = 0;

  // 1. Añadimos la nueva página a la lista
  final List<Widget> _adminPages = [
    const AdminQueueControl(),
    const AdminOffersManager(),
    const AdminStatistics(), // Nueva página
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _adminPages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.azulProfundo,
        unselectedItemColor: Colors.grey, // Opcional: para mejorar visibilidad
        type: BottomNavigationBarType.fixed, // Mantiene los iconos estables si son más de 3
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dvr), 
            label: 'Control Cola'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_offer), 
            label: 'Gestión Ofertas'
          ),
          // 2. Añadimos el nuevo botón en la barra
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart), 
            label: 'Estadísticas'
          ),
        ],
      ),
    );
  }
}