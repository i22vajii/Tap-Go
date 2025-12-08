import 'package:cloud_firestore/cloud_firestore.dart';

class QueueService {
  // Instancia de la base de datos
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. OBTENER LA COLA EN TIEMPO REAL (Para mostrar en pantalla)
  Stream<DocumentSnapshot> getQueueStream(String queueId) {
    return _db.collection('queues').doc(queueId).snapshots();
  }

  // 2. UNIRSE A LA COLA (Para el Usuario con NFC)
  // Usa una "Transacción" para evitar que dos personas tengan el mismo número
  Future<int> joinQueue(String queueId, String userId) async {
    final queueRef = _db.collection('queues').doc(queueId);
    final ticketRef = _db.collection('tickets').doc(); // ID automático

    return _db.runTransaction((transaction) async {
      DocumentSnapshot queueSnapshot = await transaction.get(queueRef);

      if (!queueSnapshot.exists) {
        throw Exception("La cola no existe");
      }

      // Leemos el último ticket dado
      int lastIssued = queueSnapshot.get('last_issued_number') ?? 0;
      int newTicketNumber = lastIssued + 1;

      // Actualizamos la cola (Incrementamos el contador)
      transaction.update(queueRef, {
        'last_issued_number': newTicketNumber,
      });

      // Creamos el ticket para el usuario
      transaction.set(ticketRef, {
        'queue_id': queueId,
        'user_id': userId,
        'ticket_number': newTicketNumber,
        'status': 'waiting', // esperando
        'timestamp': FieldValue.serverTimestamp(),
      });

      return newTicketNumber; // Devolvemos el número al usuario
    });
  }

  // 3. AVANZAR LA COLA (Para el Admin/Tienda)
  Future<void> callNext(String queueId) async {
    final queueRef = _db.collection('queues').doc(queueId);
    
    // Simplemente subimos el número de "A quién atendemos ahora"
    await queueRef.update({
      'current_number': FieldValue.increment(1),
    });
  }
}
