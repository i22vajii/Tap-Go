
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../admin/admin_root_screen.dart';

class OwnerLoginScreen extends StatelessWidget {
  const OwnerLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blancoPuro,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.azulMedianoche), onPressed: () => Navigator.pop(context))),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Bienvenido,", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.azulProfundo)),
            const Text("Inicia sesión para gestionar tu local.", style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 40),
            TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.email_outlined), hintText: "Correo", filled: true, fillColor: AppColors.grisHielo, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 20),
            TextField(obscureText: true, decoration: InputDecoration(prefixIcon: const Icon(Icons.lock_outline), hintText: "Contraseña", filled: true, fillColor: AppColors.grisHielo, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulProfundo),
                onPressed: () {
                  // NAVEGACIÓN A MODO ADMIN
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AdminRootScreen()), (route) => false);
                },
                child: const Text("INICIAR SESIÓN"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
