import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Asegúrate de que esta ruta es correcta en tu proyecto
import '../../../config/app_colors.dart';
import '../../../services/stats_service.dart';

class AdminStatistics extends StatefulWidget {
  const AdminStatistics({super.key});

  @override
  State<AdminStatistics> createState() => _AdminStatisticsState();
}

class _AdminStatisticsState extends State<AdminStatistics> {
  // Instancia del servicio
  final StatsService _statsService = StatsService(); 
  
  String? _shopId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserShop();
  }

  Future<void> _loadUserShop() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('owners').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _shopId = doc.data()?['shopID'];
            _isLoading = false;
          });
        } else {
           setState(() => _isLoading = false);
        }
      } catch (e) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    if (_shopId == null) {
      return const Scaffold(
        body: Center(child: Text("No tienes una tienda asignada en tu perfil de 'owners'.")));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Dashboard Analítico", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text("Local: $_shopId", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.azulProfundo,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Rendimiento Hoy", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildQueueKPIs(), 
          
          const SizedBox(height: 16),
          _buildAbandonmentRate(), 

          const SizedBox(height: 30),

          const Text("Análisis de Tráfico", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildPeakHoursChart(), 

          const SizedBox(height: 30),

          const Text("Operativa", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildOfferStatsSection(), 
          
          const SizedBox(height: 16),
          _buildTicketAnalysis(), 
          
          const SizedBox(height: 30),

          const Text("Evolución", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildWeeklyTrend(), 
          
          const SizedBox(height: 50), 
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGETS
  // ===========================================================================

  // 1. KPIs DE LA COLA
  Widget _buildQueueKPIs() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _statsService.getQueueKPIs(_shopId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final data = snapshot.data!;
        return Column(
          children: [
            Row(
              children: [
                _kpiCard("En Espera", data['waiting'] ?? '0', Icons.people, Colors.orange),
                const SizedBox(width: 12),
                _kpiCard("Tiempo Medio", data['avgTime'] ?? '--', Icons.timer, AppColors.turquesaVivo),
              ],
            ),
            const SizedBox(height: 12),
            _kpiCard("Clientes Atendidos Hoy", data['servedCount'] ?? '0', Icons.check_circle, Colors.green, isWide: true),
          ],
        );
      },
    );
  }

  // 2. TASA DE ABANDONO
  Widget _buildAbandonmentRate() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _statsService.getAbandonmentRate(_shopId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final data = snapshot.data!;
        if (data['total'] == 0) return const SizedBox();

        double rate = data['rate'];
        bool isBad = data['isBad'];
        int lost = data['lost'];
        int total = data['total'];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration().copyWith(
            color: isBad ? Colors.red[50] : Colors.green[50],
            border: Border.all(color: isBad ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2))
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Tasa de Abandono", style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text("${rate.toStringAsFixed(1)}%", 
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: isBad ? AppColors.alertaRojo : Colors.green)
                  ),
                  Text("$lost clientes perdidos de $total", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
              SizedBox(height: 50, width: 50, child: CircularProgressIndicator(value: rate / 100, strokeWidth: 6, backgroundColor: Colors.white, color: isBad ? AppColors.alertaRojo : Colors.green))
            ],
          ),
        );
      },
    );
  }

  // 3. GRÁFICO DE HORAS PUNTA (CORREGIDO: Sin SideTitleWidget)
  Widget _buildPeakHoursChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Horas Punta (Clientes por hora)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<Map<int, double>>(
              stream: _statsService.getPeakHours(_shopId!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final hoursMap = snapshot.data!;
                
                List<BarChartGroupData> bars = hoursMap.entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value,
                        color: entry.value > 5 ? AppColors.alertaRojo : AppColors.turquesaVivo,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      )
                    ],
                  );
                }).toList();

                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (hoursMap.values.isEmpty ? 10 : hoursMap.values.reduce((a, b) => a > b ? a : b)) + 2,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.blueGrey,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem('${group.x.toInt()}:00 \n', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), children: <TextSpan>[TextSpan(text: (rod.toY).toInt().toString(), style: const TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.w500))]);
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1, 
                          getTitlesWidget: (value, meta) {
                            int hour = value.toInt();
                            if (hour % 2 != 0) return const SizedBox.shrink(); // Solo horas pares

                            // --- CAMBIO AQUÍ: Usamos Padding en lugar de SideTitleWidget ---
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                "$hour:00", 
                                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10)
                              ),
                            );
                            // -------------------------------------------------------------
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                    barGroups: bars,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 4. OFERTAS
  Widget _buildOfferStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20), height: 250, decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Inventario Ofertas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<Map<String, int>>(
              stream: _statsService.getOfferStats(_shopId!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!;
                if (data['total'] == 0) return const Center(child: Text("Sin ofertas"));

                return Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2, centerSpaceRadius: 30,
                          sections: [
                            PieChartSectionData(value: data['activas']!.toDouble(), color: AppColors.turquesaVivo, radius: 40, showTitle: false),
                            PieChartSectionData(value: data['inactivas']!.toDouble(), color: Colors.grey.shade300, radius: 35, showTitle: false),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _legendItem("Activas", data['activas']!, AppColors.turquesaVivo),
                        const SizedBox(height: 10),
                        _legendItem("Inactivas", data['inactivas']!, Colors.grey.shade400),
                      ],
                    )
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 5. ESTADO TICKETS
  Widget _buildTicketAnalysis() {
    return Container(
      padding: const EdgeInsets.all(24), height: 250, decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Estado del Flujo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<Map<String, double>>(
              stream: _statsService.getTicketStatusStats(_shopId!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final data = snapshot.data!;

                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: data['maxY'],
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                            switch (v.toInt()) {
                              case 0: return const Padding(padding: EdgeInsets.only(top:5), child: Text('Espera', style: TextStyle(fontSize: 12)));
                              case 1: return const Padding(padding: EdgeInsets.only(top:5), child: Text('Atendidos', style: TextStyle(fontSize: 12)));
                              default: return const Text('');
                            }
                        })),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      _makeBarData(0, data['waiting']!, Colors.orange),
                      _makeBarData(1, data['served']!, AppColors.turquesaVivo),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  // 6. TENDENCIA SEMANAL (VERSIÓN CORREGIDA PARA MOSTRAR ERROR DE ÍNDICE)
  Widget _buildWeeklyTrend() {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tendencia últimos 7 días", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<List<double>>(
              stream: _statsService.getWeeklyTrend(_shopId!),
              builder: (context, snapshot) {
                // 1. PRIMERO comprobamos errores (Esto es lo que fallaba antes)
                if (snapshot.hasError) {
                   print("ERROR FIREBASE: ${snapshot.error}"); // Para que salga en consola
                   return Center(
                     child: Padding(
                       padding: const EdgeInsets.all(8.0),
                       child: SelectableText( // Selectable para que puedas copiar si hace falta
                         "Falta Índice (Mira la consola Run):\n${snapshot.error}", 
                         style: const TextStyle(color: Colors.red, fontSize: 10), 
                         textAlign: TextAlign.center
                       ),
                     )
                   );
                }

                // 2. LUEGO comprobamos carga
                if (snapshot.connectionState == ConnectionState.waiting) {
                   return const Center(child: Text("Cargando...", style: TextStyle(color: Colors.grey, fontSize: 12)));
                }

                // 3. DATOS VACÍOS
                if (!snapshot.hasData) {
                  return const Center(child: Text("Sin datos", style: TextStyle(color: Colors.grey)));
                }

                List<double> spotsData = snapshot.data!;
                if (spotsData.every((val) => val == 0)) {
                  return const Center(child: Text("Sin actividad reciente", style: TextStyle(color: Colors.grey)));
                }

                // Convertir a Spots
                List<FlSpot> spots = [];
                double maxVal = 0;
                for (int i = 0; i < spotsData.length; i++) {
                  double val = spotsData[i];
                  if(val > maxVal) maxVal = val;
                  spots.add(FlSpot(i.toDouble(), val));
                }

                return LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppColors.turquesaVivo,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.turquesaVivo.withOpacity(0.1),
                        ),
                      ),
                    ],
                    minY: 0,
                    maxY: maxVal + 5,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("-7 días", style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text("Hoy", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  // --- HELPERS ---
  Widget _kpiCard(String title, String value, IconData icon, Color color, {bool isWide = false}) {
    return Expanded(flex: isWide ? 0 : 1, child: Container(width: isWide ? double.infinity : null, padding: const EdgeInsets.all(20), decoration: _cardDecoration(), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.azulMedianoche)), Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12))])])));
  }

  Widget _legendItem(String text, int value, Color color) {
    return Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Text("$text ($value)", style: const TextStyle(fontSize: 12, color: Colors.grey))]);
  }

  BoxDecoration _cardDecoration() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]);

  BarChartGroupData _makeBarData(int x, double y, Color color) => BarChartGroupData(x: x, barRods: [BarChartRodData(toY: y, color: color, width: 25, borderRadius: BorderRadius.circular(4))]);
}