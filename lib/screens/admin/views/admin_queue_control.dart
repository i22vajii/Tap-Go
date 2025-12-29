import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../services/queue_service.dart'; 

class AdminQueueControl extends StatefulWidget {
  const AdminQueueControl({super.key});

  @override
  State<AdminQueueControl> createState() => _AdminQueueControlState();
}

class _AdminQueueControlState extends State<AdminQueueControl> {
  final QueueService _queueService = QueueService();
  
  String? _shopId;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOwnerShop();
  }

  Future<void> _loadOwnerShop() async {
    try {
      final id = await _queueService.getOwnerShopId();
      if (mounted) {
        setState(() {
          _shopId = id;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onCallNext() async {
    if (_shopId == null) return;
    try {
      await _queueService.advanceQueueSmart(_shopId!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Estados de carga inicial
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    if (_errorMessage != null || _shopId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Diagnóstico")),
        body: Center(child: Text("Error: ${_errorMessage ?? 'Sin tienda asignada'}")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Gestión de Cola", style: TextStyle(fontSize: 16)),
            Text("Tienda: $_shopId", style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Chip(
              label: Text("EN SERVICIO", style: TextStyle(color: AppColors.turquesaVivo, fontSize: 10, fontWeight: FontWeight.bold)),
              backgroundColor: AppColors.blancoPuro,
            ),
          )
        ],
      ),
      // 2. Stream conectado al servicio que devuelve Stats (NO Snapshot)
      body: StreamBuilder<AdminQueueStats>(
        stream: _queueService.getAdminStatsStream(_shopId!),
        builder: (context, snapshot) {
          
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // 3. Datos limpios directamente
          final stats = snapshot.data!;

          // 4. Caso: Cola no inicializada
          if (!stats.exists) {
            return Center(
              child: ElevatedButton(
                onPressed: () => _queueService.initializeQueue(_shopId!),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.turquesaVivo),
                child: const Text("ACTIVAR COLA (INICIALIZAR)", style: TextStyle(color: Colors.white)),
              ),
            );
          }

          // 5. Interfaz Principal
          return Column(
            children: [
              // Dashboard Superior
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.azulProfundo,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(stats.waitingCount.toString(), "Esperando"),
                    _stat(stats.avgTimeFormatted, "T. Medio"),
                    _stat(stats.currentNumber.toString(), "Atendidos")
                  ],
                ),
              ),
              
              // Zona de Control
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text("TURNO ACTUAL", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.blancoPuro,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]
                          ),
                          child: Column(
                            children: [
                              Text("#${stats.currentNumber}", style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: AppColors.azulMedianoche)),
                              const SizedBox(height: 20),
                              
                              SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: stats.hasPeopleWaiting ? AppColors.turquesaVivo : Colors.grey.shade300,
                                  ),
                                  onPressed: stats.hasPeopleWaiting ? _onCallNext : null, 
                                  child: Text(
                                    stats.hasPeopleWaiting ? "LLAMAR AL SIGUIENTE" : "NADIE EN ESPERA", 
                                    style: TextStyle(
                                      color: stats.hasPeopleWaiting ? Colors.white : Colors.grey.shade600, 
                                      fontWeight: FontWeight.bold
                                    )
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 10),
                              
                              OutlinedButton(
                                onPressed: stats.hasPeopleWaiting ? _onCallNext : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.alertaRojo,
                                  side: BorderSide(color: stats.hasPeopleWaiting ? AppColors.alertaRojo : Colors.grey.shade300)
                                ),
                                child: const Text("NO PRESENTADO"),
                              )
                            ]
                          )
                        ),
                        
                        const SizedBox(height: 20),
                        
                         const Align(alignment: Alignment.centerLeft, child: Text("Siguientes:", style: TextStyle(fontWeight: FontWeight.bold))),
                         if (stats.waitingCount > 0) _next("#${stats.currentNumber + 1}", "Prepárate"),
                         if (stats.waitingCount > 1) _next("#${stats.currentNumber + 2}", "En espera"),
                         if (stats.waitingCount == 0) const Padding(padding: EdgeInsets.only(top:20), child: Text("No hay nadie más en la cola", style: TextStyle(color: Colors.grey))),
                      ]
                    )
                  )
                )
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _stat(String v, String l) => Column(children: [Text(v, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10))]);

  Widget _next(String t, String w) => ListTile(
    leading: CircleAvatar(backgroundColor: AppColors.grisHielo, child: Text(t, style: const TextStyle(color: AppColors.azulMedianoche, fontSize: 12))),
    title: const Text("Cliente en espera"),
    trailing: Text(w, style: const TextStyle(color: Colors.grey)),
  );
}