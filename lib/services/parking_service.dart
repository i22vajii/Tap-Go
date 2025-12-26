import 'package:cloud_firestore/cloud_firestore.dart';

class ParkingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String collection = 'tickets_parking';

  // 1. BUSCAR TICKET ACTIVO
  Future<String?> findActiveTicketId(String userId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection(collection)
          .where('usuario_uid', isEqualTo: userId)
          .where('estado', whereIn: ['pendiente', 'validado'])
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      print("Error buscando ticket activo: $e");
      return null;
    }
  }

  // 2. OBTENER STREAM DEL TICKET
  Stream<DocumentSnapshot> getTicketStream(String ticketId) {
    return _db.collection(collection).doc(ticketId).snapshots();
  }

  // 3. ENTRAR AL PARKING
  // shop_id ya viene limpio desde la vista (sin "parking_")
  Future<String> checkIn(String shop_id) async {
    DocumentReference ref = _db.collection(collection).doc(); 

    await ref.set({
      'entrada': FieldValue.serverTimestamp(),
      'estado': 'pendiente', 
      'coste': 0.0,
      'shopID': shop_id.trim(), // Aseguramos limpieza
    });

    return ref.id;
  }

  // 4. SALIR DEL PARKING
  Future<void> checkOut(String ticketId) async {
    await _db.collection(collection).doc(ticketId).update({
      'estado': 'finalizado',
      'salida': FieldValue.serverTimestamp(),
    });
  }
}