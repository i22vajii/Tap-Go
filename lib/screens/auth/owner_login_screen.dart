import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../admin/admin_root_screen.dart';

class OwnerLoginScreen extends StatefulWidget {
  const OwnerLoginScreen({super.key});

  @override
  State<OwnerLoginScreen> createState() => _OwnerLoginScreenState();
}

class _OwnerLoginScreenState extends State<OwnerLoginScreen> {
  // Controladores
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Estado de carga
  bool _isLoading = false;

  // --- NUEVO: Variable para controlar la visibilidad de la contraseña ---
  bool _isObscure = true; 

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, rellena todos los campos")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().loginOwner(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminRootScreen()),
          (route) => false,
        );
      }

    } on FirebaseAuthException catch (e) {
      // IMPRIMIR EL ERROR EN LA CONSOLA DE VS CODE
      print("ERROR REAL FIREBASE: ${e.code} - ${e.message}");

      // MOSTRAR EL CÓDIGO DE ERROR EN LA PANTALLA
      String message = "Error: ${e.code} - ${e.message}";
      
      if (e.code == 'not-owner') {
        message = "No tienes permisos de administrador.";
      } else if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        message = "Usuario o contraseña incorrectos.";
      } else if (e.code == 'wrong-password') {
        message = "Contraseña incorrecta.";
      } else if (e.code == 'invalid-email') {
        message = "El formato del correo no es válido.";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.alertaRojo,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error inesperado: $e"),
            backgroundColor: AppColors.alertaRojo,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blancoPuro,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.azulMedianoche),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 60, color: AppColors.azulProfundo),
              const SizedBox(height: 20),
              const Text(
                "Acceso Profesional",
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.azulProfundo),
              ),
              const Text(
                "Inicia sesión para gestionar tu local.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // CAMPO EMAIL
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.azulProfundo),
                  hintText: "Correo electrónico",
                  filled: true,
                  fillColor: AppColors.grisHielo,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- NUEVO: CAMPO PASSWORD CON OJITO ---
              TextField(
                controller: _passwordController,
                obscureText: _isObscure, // 1. Usamos la variable aquí
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.azulProfundo),
                  
                  // 2. Añadimos el icono a la derecha (suffixIcon)
                  suffixIcon: IconButton(
                    icon: Icon(
                      // Cambiamos el icono según el estado
                      _isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      // 3. Al pulsar, invertimos el valor true/false
                      setState(() {
                        _isObscure = !_isObscure;
                      });
                    },
                  ),
                  
                  hintText: "Contraseña",
                  filled: true,
                  fillColor: AppColors.grisHielo,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),

              // BOTÓN DE LOGIN
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azulProfundo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    disabledBackgroundColor: AppColors.azulProfundo.withOpacity(0.7),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "ENTRAR AL SISTEMA",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}