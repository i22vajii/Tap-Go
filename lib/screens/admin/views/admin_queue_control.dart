import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Asegúrate de que esta ruta es correcta en tu proyecto
import '../../../config/app_colors.dart';

class AdminQueueControl extends StatefulWidget {
  const AdminQueueControl({super.key});

  @override
  State<AdminQueueControl> createState() => _AdminQueueControlState();
}

class _AdminQueueControlState extends State<AdminQueueControl> {
  String? _shopId;
  String? _userUid;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarDatosDelLocal();
  }

  // 1. Obtener la tienda del dueño actual
  Future<void> _cargarDatosDelLocal() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "No hay sesión activa";
      
      setState(() => _userUid = user.uid);

      // Buscamos en la colección 'owners'
      final doc = await FirebaseFirestore.instance.collection('owners').doc(user.uid).get();
      
      if (!doc.exists) {
        setState(() {
          _errorMessage = "NO_OWNER_DOC";
          _isLoading = false;
        });
        return;
      }

      final data = doc.data();
      String? shopIdLeido = data?['shopID']; 

      if (shopIdLeido == null || shopIdLeido.isEmpty) {
         setState(() {
          _errorMessage = "EMPTY_SHOP_ID";
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _shopId = shopIdLeido;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // 2. Crear la cola si no existe (con campos para estadísticas)
  Future<void> _inicializarCola() async {
    if (_shopId == null) return;
    try {
      await FirebaseFirestore.instance.collection('queues').doc(_shopId).set({
        'current_number': 0,
        'last_issued_number': 0,
        'served_count': 0,         
        'total_service_seconds': 0, 
        'last_call_time': FieldValue.serverTimestamp(), 
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // 3. Lógica inteligente: Avanzar turno (con protección si no hay nadie)
  Future<void> _llamarSiguiente() async {
    if (_shopId == null) return;

    final docRef = FirebaseFirestore.instance.collection('queues').doc(_shopId);

    // Usamos una transacción para seguridad
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);

      if (!snapshot.exists) return;

      // Obtener datos actuales
      int current = snapshot.get('current_number') ?? 0;
      int lastIssued = snapshot.get('last_issued_number') ?? 0; // Necesitamos saber el último ticket dado
      
      // --- CORRECCIÓN CLAVE: Si ya vamos por el último número, NO avanzamos ---
      if (current >= lastIssued) {
        return; 
      }

      int servedCount = snapshot.get('served_count') ?? 0;
      int totalSeconds = snapshot.get('total_service_seconds') ?? 0;
      
      // Comprobar tiempo
      dynamic lastCallRaw = (snapshot.data() as Map<String, dynamic>).containsKey('last_call_time') 
          ? snapshot.get('last_call_time') 
          : null;
      
      Timestamp? lastCall = lastCallRaw is Timestamp ? lastCallRaw : null;

      // Calcular diferencia de tiempo
      int secondsDiff = 0;
      int newServedCount = servedCount;
      int newTotalSeconds = totalSeconds;

      if (lastCall != null) {
        final now = DateTime.now();
        final last = lastCall.toDate();
        final diff = now.difference(last).inSeconds;

        if (diff < 1200 && diff > 0) { 
          secondsDiff = diff;
          newServedCount += 1; 
          newTotalSeconds += secondsDiff;
        }
      } else {
        newServedCount += 1;
      }

      // Guardar cambios
      transaction.update(docRef, {
        'current_number': current + 1,
        'served_count': newServedCount,
        'total_service_seconds': newTotalSeconds,
        'last_call_time': FieldValue.serverTimestamp(),
      });
    });
  }

  String _formatAvgTime(int totalSeconds, int count) {
    if (count == 0) return "--";
    int avgSeconds = (totalSeconds / count).round();
    int m = avgSeconds ~/ 60;
    int s = avgSeconds % 60;
    return "${m}m ${s}s";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_errorMessage != null || _shopId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Diagnóstico")),
        body: Center(child: Text("Error: ${_errorMessage ?? 'Sin tienda'}")),
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('queues').doc(_shopId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          if (!snapshot.data!.exists) {
            return Center(
              child: ElevatedButton(
                onPressed: _inicializarCola,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.turquesaVivo),
                child: const Text("ACTIVAR COLA (INICIALIZAR)", style: TextStyle(color: Colors.white)),
              ),
            );
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          int current = data['current_number'] ?? 0;
          int lastIssued = data['last_issued_number'] ?? 0;
          
          int servedCount = data['served_count'] ?? 0;
          int totalSeconds = data['total_service_seconds'] ?? 0;
          String avgTimeStr = _formatAvgTime(totalSeconds, servedCount);

          int waitingCount = (lastIssued - current);
          if (waitingCount < 0) waitingCount = 0;

          // --- VARIABLE PARA CONTROLAR EL ESTADO DEL BOTÓN ---
          bool hayGenteEsperando = waitingCount > 0;

          return Column(
            children: [
              // Dashboard Superior
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.azulProfundo,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(waitingCount.toString(), "Esperando"),
                    _stat(avgTimeStr, "T. Medio"),
                    _stat(current.toString(), "Atendidos")
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
                              Text("#$current", style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: AppColors.azulMedianoche)),
                              const SizedBox(height: 20),
                              
                              SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    // Cambia el color a gris si no hay gente
                                    backgroundColor: hayGenteEsperando ? AppColors.turquesaVivo : Colors.grey.shade300,
                                  ),
                                  // Si no hay gente, onPressed es null (deshabilita el botón)
                                  onPressed: hayGenteEsperando ? _llamarSiguiente : null, 
                                  child: Text(
                                    hayGenteEsperando ? "LLAMAR AL SIGUIENTE" : "NADIE EN ESPERA", 
                                    style: TextStyle(
                                      color: hayGenteEsperando ? Colors.white : Colors.grey.shade600, 
                                      fontWeight: FontWeight.bold
                                    )
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 10),
                              
                              OutlinedButton(
                                onPressed: hayGenteEsperando ? _llamarSiguiente : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.alertaRojo,
                                  side: BorderSide(color: hayGenteEsperando ? AppColors.alertaRojo : Colors.grey.shade300)
                                ),
                                child: const Text("NO PRESENTADO"),
                              )
                            ]
                          )
                        ),
                        
                        const SizedBox(height: 20),
                        
                         const Align(alignment: Alignment.centerLeft, child: Text("Siguientes:", style: TextStyle(fontWeight: FontWeight.bold))),
                         if (waitingCount > 0) _next("#${current + 1}", "Prepárate"),
                         if (waitingCount > 1) _next("#${current + 2}", "En espera"),
                         if (waitingCount == 0) const Padding(padding: EdgeInsets.only(top:20), child: Text("No hay nadie más en la cola", style: TextStyle(color: Colors.grey))),
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