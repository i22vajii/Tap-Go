import 'package:cloud_firestore/cloud_firestore.dart';

class StatsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. KPIs DE LA COLA (Usa el ID del documento 'queues' directamente)
  Stream<Map<String, dynamic>> getQueueKPIs(String shopId) {
    return _db.collection('queues').doc(shopId).snapshots().map((doc) {
      if (!doc.exists) return {};
      
      final data = doc.data() as Map<String, dynamic>;
      int current = (data['current_number'] as num?)?.toInt() ?? 0;
      int lastIssued = (data['last_issued_number'] as num?)?.toInt() ?? 0;
      int servedCount = (data['served_count'] as num?)?.toInt() ?? 0;
      int totalSeconds = (data['total_service_seconds'] as num?)?.toInt() ?? 0;

      int waiting = lastIssued - current;
      if (waiting < 0) waiting = 0;

      String avgTime = "--";
      if (servedCount > 0) {
        int avgSec = (totalSeconds / servedCount).round();
        int m = avgSec ~/ 60;
        int s = avgSec % 60;
        avgTime = "${m}m ${s}s";
      }

      return {
        'waiting': waiting.toString(),
        'avgTime': avgTime,
        'servedCount': servedCount.toString(),
      };
    });
  }

  // 2. TASA DE ABANDONO (Colección TICKETS -> usa 'queue_id')
  Stream<Map<String, dynamic>> getAbandonmentRate(String shopId) {
    return _db.collection('tickets')
        .where('queue_id', isEqualTo: shopId) 
        .snapshots()
        .map((snapshot) {
      
      if (snapshot.docs.isEmpty) return {'rate': 0.0, 'lost': 0, 'total': 0, 'isBad': false};

      int total = snapshot.docs.length;
      int lost = snapshot.docs.where((d) {
        final status = d['status'];
        return status == 'cancelled' || status == 'no-show' || status == 'cancelado';
      }).length;

      double rate = total > 0 ? (lost / total) * 100 : 0.0;
      
      return {
        'rate': rate,
        'lost': lost,
        'total': total,
        'isBad': rate > 15
      };
    });
  }

  // 3. HORAS PUNTA (Colección TICKETS -> usa 'queue_id')
  Stream<Map<int, double>> getPeakHours(String shopId) {
    return _db.collection('tickets')
        .where('queue_id', isEqualTo: shopId) 
        .snapshots()
        .map((snapshot) {
      
      Map<int, double> hoursMap = {for (var i = 8; i <= 22; i++) i: 0.0};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Importante: timestamp debe ser un campo Timestamp en Firebase
        if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
          Timestamp ts = data['timestamp'];
          int hour = ts.toDate().hour;
          if (hoursMap.containsKey(hour)) {
            hoursMap[hour] = hoursMap[hour]! + 1.0;
          }
        }
      }
      return hoursMap;
    });
  }

  // 4. OFERTAS (Colección OFERTAS -> usa 'shopID')
  Stream<Map<String, int>> getOfferStats(String shopId) {
    return _db.collection('ofertas')
        .where('shopID', isEqualTo: shopId) 
        .snapshots()
        .map((snapshot) {
      
      int activas = 0;
      int inactivas = 0;

      for (var doc in snapshot.docs) {
        bool isActive = doc['activa'] == true;
        if (isActive) activas++; else inactivas++;
      }

      return {
        'activas': activas,
        'inactivas': inactivas,
        'total': snapshot.docs.length
      };
    });
  }

  // 5. ESTADO TICKETS (Colección TICKETS -> usa 'queue_id')
  Stream<Map<String, double>> getTicketStatusStats(String shopId) {
    return _db.collection('tickets')
        .where('queue_id', isEqualTo: shopId) 
        .snapshots()
        .map((snapshot) {
      
      int waiting = 0;
      int served = 0;

      for (var doc in snapshot.docs) {
        String status = doc['status'] ?? '';
        if (status == 'waiting' || status == 'esperando') waiting++;
        if (status == 'served' || status == 'completed' || status == 'atendido' || status == 'servido') served++;
      }

      return {
        'waiting': waiting.toDouble(),
        'served': served.toDouble(),
        'maxY': (snapshot.docs.length + 5).toDouble()
      };
    });
  }

  // 6. TENDENCIA SEMANAL (Colección TICKETS -> usa 'queue_id')
  Stream<List<double>> getWeeklyTrend(String shopId) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    return _db.collection('tickets')
        .where('queue_id', isEqualTo: shopId) 
        .where('timestamp', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('timestamp') 
        .snapshots()
        .map((snapshot) {
          
      List<double> dailyCounts = List.filled(7, 0.0);

      for (var doc in snapshot.docs) {
        Timestamp ts = doc['timestamp'];
        DateTime date = ts.toDate();
        int diff = now.difference(date).inDays;
        
        if (diff >= 0 && diff < 7) {
          int index = 6 - diff; 
          dailyCounts[index] += 1.0;
        }
      }
      return dailyCounts;
    });
  }
}