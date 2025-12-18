import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../config/app_colors.dart';

class AdminStatistics extends StatelessWidget {
  const AdminStatistics({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analítica del Negocio"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ofertas').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error al cargar datos"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          int totalOfertas = docs.length;
          int activas = docs.where((d) => d['activa'] == true).length;
          int inactivas = totalOfertas - activas;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Estado de Ofertas",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.azulProfundo),
                ),
                const SizedBox(height: 20),
                
                // CORRECCIÓN: aspectRatio en lugar de aspectSize
                AspectRatio(
                  aspectRatio: 1.3, 
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          value: activas.toDouble() > 0 ? activas.toDouble() : 0.1,
                          title: 'Activas',
                          color: AppColors.turquesaVivo,
                          radius: 60,
                          // CORRECCIÓN: titleStyle en lugar de titleTextStyle
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: inactivas.toDouble() > 0 ? inactivas.toDouble() : 0.1,
                          title: 'Inactivas',
                          color: AppColors.alertaRojo,
                          radius: 55,
                          // CORRECCIÓN: titleStyle en lugar de titleTextStyle
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),
                const Text(
                  "Métricas Clave",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.azulProfundo),
                ),
                const SizedBox(height: 15),

                Row(
                  children: [
                    _statCard("Total", totalOfertas.toString(), Icons.analytics, Colors.blue),
                    const SizedBox(width: 15),
                    _statCard("Activas", activas.toString(), Icons.check_circle, Colors.green),
                  ],
                ),
                
                const SizedBox(height: 30),
                const Text(
                  "Actividad Semanal",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.azulProfundo),
                ),
                const SizedBox(height: 15),

                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      barGroups: [
                        _makeGroupData(0, 5),
                        _makeGroupData(1, 8),
                        _makeGroupData(2, 12),
                        _makeGroupData(3, 7),
                        _makeGroupData(4, 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: AppColors.azulProfundo,
          width: 18,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}