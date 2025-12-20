import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../config/app_colors.dart';

class AdminStatistics extends StatelessWidget {
  const AdminStatistics({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Dashboard en Tiempo Real"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildQueueStatusSection(), // Nueva sección de Cola
          const SizedBox(height: 24),
          _buildOfferStatsSection(),  // Gráfico circular de Ofertas
          const SizedBox(height: 24),
          _buildTicketActivitySection(), // Gráfico de barras de Tickets
        ],
      ),
    );
  }

  // 1. Métrica de Cola (Basado en tu captura de 'queues')
  Widget _buildQueueStatusSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('queues').doc('tienda_01').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        var data = snapshot.data!.data() as Map<String, dynamic>;
        
        int actual = data['current_number'] ?? 0;
        int total = data['last_issued_number'] ?? 0;
        int esperando = total - actual;

        return Row(
          children: [
            _miniStatCard("En Espera", esperando.toString(), Icons.people_outline, Colors.orange),
            const SizedBox(width: 12),
            _miniStatCard("Atendidos", actual.toString(), Icons.check_circle_outline, Colors.green),
          ],
        );
      },
    );
  }

  // 2. Gráfico Circular de Ofertas (Basado en tu captura de 'ofertas')
  Widget _buildOfferStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Distribución de Ofertas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('ofertas').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              int activas = snapshot.data!.docs.where((d) => d['activa'] == true).length;
              int inactivas = snapshot.data!.docs.length - activas;

              return SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        value: activas.toDouble(),
                        title: 'Activas',
                        color: AppColors.turquesaVivo,
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        value: inactivas.toDouble(),
                        title: 'Off',
                        color: AppColors.alertaRojo,
                        radius: 45,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 3. Actividad de Tickets (Basado en tu captura de 'tickets')
  Widget _buildTicketActivitySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Actividad de Tickets", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tickets').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              
              // Aquí contamos cuántos tickets hay por estado
              int waiting = snapshot.data!.docs.where((d) => d['status'] == 'waiting').length;
              
              return SizedBox(
                height: 150,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    barGroups: [
                      _makeBarData(0, waiting.toDouble(), Colors.blue),
                      _makeBarData(1, snapshot.data!.docs.length.toDouble(), AppColors.azulProfundo),
                    ],
                  ),
                ),
              );
            },
          ),
          const Center(child: Text("Tickets esperando vs Total histórico", style: TextStyle(fontSize: 11, color: Colors.grey))),
        ],
      ),
    );
  }

  // --- Helpers de Diseño ---

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
    );
  }

  Widget _miniStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeBarData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 30,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }
}