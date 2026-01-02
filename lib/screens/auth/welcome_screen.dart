
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../client/client_root_screen.dart';
import 'owner_login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blancoPuro,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const SizedBox(height: 40),
                  CircleAvatar(
                    radius: 60, 
                    backgroundColor: AppColors.aquaSuave.withOpacity(0.3),
                    backgroundImage: const AssetImage('media/logo.png'), 
                  ),
                  const SizedBox(height: 24),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(text: 'Tap', style: TextStyle(color: AppColors.azulProfundo)),
                        TextSpan(text: '&', style: TextStyle(color: AppColors.turquesaVivo)),
                        TextSpan(text: 'Go', style: TextStyle(color: AppColors.turquesaVivo)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("Gestiona tu tiempo, no tu espera.", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        // NAVEGACIÓN A MODO CLIENTE
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientRootScreen()));
                      },
                      child: const Text("SOY CLIENTE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [Expanded(child: Divider(color: Colors.grey[300])), Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text("o", style: TextStyle(color: Colors.grey[400]))), Expanded(child: Divider(color: Colors.grey[300]))]),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        // NAVEGACIÓN A LOGIN DUEÑO
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerLoginScreen()));
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.azulProfundo, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("ACCESO PROFESIONALES", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.azulProfundo, letterSpacing: 1.0)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
