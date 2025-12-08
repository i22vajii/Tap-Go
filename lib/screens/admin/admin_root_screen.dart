
import 'package:flutter/material.dart';
import 'views/admin_queue_control.dart';
import 'views/admin_offers_manager.dart';
import '../../config/app_colors.dart';

class AdminRootScreen extends StatefulWidget {
  const AdminRootScreen({super.key});
  @override
  State<AdminRootScreen> createState() => _AdminRootScreenState();
}

class _AdminRootScreenState extends State<AdminRootScreen> {
  int _currentIndex = 0;
  final List<Widget> _adminPages = [const AdminQueueControl(), const AdminOffersManager()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _adminPages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.azulProfundo,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dvr), label: 'Control Cola'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer), label: 'Gestión Ofertas'),
        ],
      ),
    );
  }
}
