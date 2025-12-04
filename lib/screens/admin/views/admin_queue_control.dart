
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

class AdminQueueControl extends StatelessWidget {
  const AdminQueueControl({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestión de Cola"), actions: [const Padding(padding: EdgeInsets.only(right: 16), child: Chip(label: Text("EN SERVICIO", style: TextStyle(color: AppColors.turquesaVivo, fontSize: 10, fontWeight: FontWeight.bold)), backgroundColor: AppColors.blancoPuro))]),
      body: Column(
        children: [
          Container(padding: const EdgeInsets.all(16), color: AppColors.azulProfundo, child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_stat("12", "Esperando"), _stat("4m", "T. Medio"), _stat("85", "Atendidos")])),
          Expanded(
            child: SingleChildScrollView( // Añadido Scroll para evitar overflow
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text("TURNO ACTUAL", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: AppColors.blancoPuro, borderRadius: BorderRadius.circular(24)),
                      child: Column(
                        children: [
                          const Text("A-45", style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: AppColors.azulMedianoche)),
                          const SizedBox(height: 20),
                          SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: (){}, child: const Text("LLAMAR AL SIGUIENTE"))),
                          const SizedBox(height: 10),
                          OutlinedButton(onPressed: (){}, style: OutlinedButton.styleFrom(foregroundColor: AppColors.alertaRojo, side: const BorderSide(color: AppColors.alertaRojo)), child: const Text("NO PRESENTADO"))
                        ]
                      )
                    ),
                    const SizedBox(height: 30),
                    const Align(alignment: Alignment.centerLeft, child: Text("Siguientes:", style: TextStyle(fontWeight: FontWeight.bold))),
                    _next("A-46", "3 min"),
                    _next("A-47", "5 min")
                  ]
                )
              )
            )
          ),
        ],
      ),
    );
  }
  Widget _stat(String v, String l) => Column(children: [Text(v, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10))]);
  Widget _next(String t, String w) => ListTile(leading: CircleAvatar(backgroundColor: AppColors.grisHielo, child: Text(t, style: const TextStyle(color: AppColors.azulMedianoche))), title: const Text("Cliente"), trailing: Text(w));
}
