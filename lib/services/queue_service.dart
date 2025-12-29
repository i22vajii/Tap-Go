import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==========================================
// 1. MODELOS DE DATOS (DTOs)
// ==========================================

/// Modelo optimizado para la vista del ADMIN (Dashboard)
class AdminQueueStats {
  final int currentNumber;
  final int waitingCount;
  final int servedCount;
  final String avgTimeFormatted;
  final bool hasPeopleWaiting;
  final bool exists;

  AdminQueueStats({
    required this.currentNumber,
    required this.waitingCount,
    required this.servedCount,
    required this.avgTimeFormatted,
    required this.hasPeopleWaiting,
    required this.exists,
  });
}

/// Modelo optimizado para la vista del CLIENTE (Pantalla de espera)
class QueueMetrics {
  final int currentServing;
  final int peopleAhead;
  final bool isMyTurn;
  final String formattedWaitTime;

  QueueMetrics({
    required this.currentServing,
    required this.peopleAhead,
    required this.isMyTurn,
    required this.formattedWaitTime,
  });
}

// ==========================================
// 2. SERVICIO PRINCIPAL
// ==========================================

class QueueService {
  // Instancias singleton de Firebase
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ---------------------------------------------------------
  // SECCIÓN A: MÉTODOS PARA EL ADMINISTRADOR (DUEÑO)
  // ---------------------------------------------------------

  /// 1. Obtiene el ID de la tienda asociado al usuario logueado.
  Future<String> getOwnerShopId() async {
    final user = _auth.currentUser;
    if (user == null) throw "No hay sesión activa";

    final doc = await _db.collection('owners').doc(user.uid).get();
    
    if (!doc.exists) {
      throw "El usuario no está registrado como dueño en la base de datos.";
    }

    final data = doc.data();
    final shopId = data?['shopID'];

    if (shopId == null || shopId.toString().isEmpty) {
      throw "El dueño no tiene una tienda asignada (shopID vacío).";
    }

    return shopId;
  }

  /// 2. Crea o reinicia la cola en la base de datos si no existe.
  Future<void> initializeQueue(String shopId) async {
    await _db.collection('queues').doc(shopId).set({
      'current_number': 0,
      'last_issued_number': 0,
      'served_count': 0,
      'total_service_seconds': 0,
      'last_call_time': FieldValue.serverTimestamp(),
    });
  }

  /// 3. Stream que devuelve los datos YA PROCESADOS para el Admin.
  /// La vista no necesita importar Cloud Firestore gracias a esto.
  Stream<AdminQueueStats> getAdminStatsStream(String shopId) {
    return _db.collection('queues').doc(shopId).snapshots().map((doc) {
      return _calculateAdminStats(doc);
    });
  }

  /// 4. Lógica interna para calcular estadísticas del Admin.
  AdminQueueStats _calculateAdminStats(DocumentSnapshot doc) {
    if (!doc.exists) {
      return AdminQueueStats(
        currentNumber: 0, waitingCount: 0, servedCount: 0, 
        avgTimeFormatted: "--", hasPeopleWaiting: false, exists: false
      );
    }

    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    int current = data['current_number'] ?? 0;
    int lastIssued = data['last_issued_number'] ?? 0;
    int servedCount = data['served_count'] ?? 0;
    int totalSeconds = data['total_service_seconds'] ?? 0;

    int waitingCount = (lastIssued - current);
    if (waitingCount < 0) waitingCount = 0;

    // Calcular tiempo medio formateado
    String avgTimeStr = "--";
    if (servedCount > 0) {
      int avgSeconds = (totalSeconds / servedCount).round();
      int m = avgSeconds ~/ 60;
      int s = avgSeconds % 60;
      avgTimeStr = "${m}m ${s}s";
    }

    return AdminQueueStats(
      currentNumber: current,
      waitingCount: waitingCount,
      servedCount: servedCount,
      avgTimeFormatted: avgTimeStr,
      hasPeopleWaiting: waitingCount > 0,
      exists: true,
    );
  }

  /// 5. Avanza el turno de forma inteligente (Transacción).
  /// Calcula el tiempo que se tardó en atender al cliente anterior.
  Future<void> advanceQueueSmart(String shopId) async {
    final docRef = _db.collection('queues').doc(shopId);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw "La cola no existe";

      int current = snapshot.get('current_number') ?? 0;
      int lastIssued = snapshot.get('last_issued_number') ?? 0;

      // Si no hay nadie esperando, no hacemos nada
      if (current >= lastIssued) return; 

      int servedCount = snapshot.get('served_count') ?? 0;
      int totalSeconds = snapshot.get('total_service_seconds') ?? 0;
      
      // Obtenemos la última vez que se llamó a alguien
      dynamic lastCallRaw = (snapshot.data() as Map<String, dynamic>)['last_call_time'];
      Timestamp? lastCall = (lastCallRaw is Timestamp) ? lastCallRaw : null;

      int newServedCount = servedCount;
      int newTotalSeconds = totalSeconds;

      // Lógica de tiempo: Si la diferencia es lógica (ej: > 0 y < 20 min), sumamos al promedio
      if (lastCall != null) {
        final diff = DateTime.now().difference(lastCall.toDate()).inSeconds;
        if (diff > 0 && diff < 1200) { 
          newServedCount += 1;
          newTotalSeconds += diff;
        }
      } else {
        // Primera llamada tras reinicio, solo aumentamos el contador sin sumar tiempo
        newServedCount += 1;
      }

      transaction.update(docRef, {
        'current_number': current + 1,
        'served_count': newServedCount,
        'total_service_seconds': newTotalSeconds,
        'last_call_time': FieldValue.serverTimestamp(),
      });
    });
  }

  // ---------------------------------------------------------
  // SECCIÓN B: MÉTODOS PARA EL CLIENTE (USUARIO)
  // ---------------------------------------------------------

  /// 1. Obtiene el Stream "crudo" de la cola (Usado por ActiveQueueView).
  Stream<DocumentSnapshot> getQueueStream(String queueId) {
    return _db.collection('queues').doc(queueId).snapshots();
  }

  /// 2. Permite a un usuario unirse a la cola.
  /// Devuelve el número de ticket asignado.
  Future<int> joinQueue(String queueId, String userId) async {
    final queueRef = _db.collection('queues').doc(queueId);
    final ticketRef = _db.collection('tickets').doc(); // ID auto-generado

    return _db.runTransaction((transaction) async {
      DocumentSnapshot queueSnapshot = await transaction.get(queueRef);

      if (!queueSnapshot.exists) {
        throw Exception("Esta tienda no tiene una cola activa.");
      }

      // Leemos el último ticket dado
      int lastIssued = queueSnapshot.get('last_issued_number') ?? 0;
      int newTicketNumber = lastIssued + 1;

      // Actualizamos la cola (Incrementamos contador)
      transaction.update(queueRef, {
        'last_issued_number': newTicketNumber,
      });

      // Creamos el ticket personal para el usuario
      transaction.set(ticketRef, {
        'queue_id': queueId,
        'user_id': userId,
        'ticket_number': newTicketNumber,
        'status': 'waiting',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return newTicketNumber;
    });
  }

  /// 3. Calcula las métricas para el cliente (Tiempo de espera estimado).
  /// Transforma un DocumentSnapshot crudo en un objeto QueueMetrics limpio.
  QueueMetrics calculateMetrics(DocumentSnapshot doc, int myTicketNumber) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Helpers seguros
    int safeInt(dynamic val) => (val is num) ? val.toInt() : int.tryParse(val.toString()) ?? 0;
    num safeNum(dynamic val) => (val is num) ? val : num.tryParse(val.toString()) ?? 0;

    int currentServing = safeInt(data['current_number']);
    int peopleAhead = myTicketNumber - currentServing;
    bool isMyTurn = peopleAhead <= 0;

    // Cálculo del tiempo estimado
    String formattedTime = "0 min"; 

    if (peopleAhead > 0) {
      num totalServiceSeconds = safeNum(data['total_service_seconds']);
      int servedCounts = safeInt(data['served_count']);
      double avgSecondsPerPerson;

      if (servedCounts > 0) {
        avgSecondsPerPerson = (totalServiceSeconds / servedCounts).toDouble();
      } else {
        avgSecondsPerPerson = 120.0; // 2 min por defecto si no hay datos históricos
      }

      double totalSecondsWait = peopleAhead * avgSecondsPerPerson;
      int minutes = totalSecondsWait ~/ 60;
      int seconds = (totalSecondsWait % 60).toInt();

      if (minutes > 0) {
        formattedTime = "$minutes min $seconds s";
      } else {
        formattedTime = "$seconds s";
      }
    }

    return QueueMetrics(
      currentServing: currentServing,
      peopleAhead: peopleAhead,
      isMyTurn: isMyTurn,
      formattedWaitTime: formattedTime,
    );
  }
}