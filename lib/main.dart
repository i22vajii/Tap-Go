import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 1. Importar el Core
import 'firebase_options.dart'; // 2. Importar la configuración generada
import 'screens/auth/welcome_screen.dart'; // Importa tu pantalla principal
import 'config/app_colors.dart'; // Importa tus colores

// 3. Convertir el main en 'async'
void main() async {
  // 4. Esta línea es OBLIGATORIA si usas async en el main
  WidgetsFlutterBinding.ensureInitialized();

  // 5. Inicializar Firebase conectando con la configuración de tu proyecto
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Virtual Queue App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Usamos tus colores personalizados para el tema base
        scaffoldBackgroundColor: AppColors.grisHielo,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.turquesaVivo),
        useMaterial3: true,
      ),
      // Tu pantalla de inicio
      home: const WelcomeScreen(),
    );
  }
}