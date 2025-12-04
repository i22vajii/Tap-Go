
import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../screens/auth/welcome_screen.dart';

class TapAndGoApp extends StatelessWidget {
  const TapAndGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tap&Go Prototype',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.grisHielo,
        primaryColor: AppColors.turquesaVivo,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.azulProfundo,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.turquesaVivo,
            foregroundColor: AppColors.blancoPuro,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      home: const WelcomeScreen(), // PUNTO DE PARTIDA
    );
  }
}
