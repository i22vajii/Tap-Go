import 'package:cloud_firestore/cloud_firestore.dart';

class ParkingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String collection = 'tickets_parking';

  // 1. BUSCAR TICKET ACTIVO (Para saber si el usuario ya está dentro)
  // Devuelve el ID del ticket si existe, o null si no.
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

  // 2. OBTENER STREAM DEL TICKET (Para ver cambios en tiempo real: validado/pagado)
  Stream<DocumentSnapshot> getTicketStream(String ticketId) {
    return _db.collection(collection).doc(ticketId).snapshots();
  }

  // 3. ENTRAR AL PARKING (Crear Ticket)
  Future<String> checkIn(String userId, String gateId, String matricula) async {
    // Referencia al nuevo documento
    DocumentReference ref = _db.collection(collection).doc(); 

    await ref.set({
      'matricula': matricula,
      'entrada': FieldValue.serverTimestamp(),
      'estado': 'pendiente', // Estados: pendiente, validado, pagado, finalizado
      'coste': 0.0,
      'usuario_uid': userId,
      'gate_id': gateId, // "Puerta Norte", "Sótano 1", etc.
    });

    return ref.id; // Devolvemos el ID del ticket creado
  }

  // 4. SALIR DEL PARKING (Finalizar Demo)
  // En una app real, esto sucedería al salir por la barrera
  Future<void> checkOut(String ticketId) async {
    await _db.collection(collection).doc(ticketId).update({
      'estado': 'finalizado',
      'salida': FieldValue.serverTimestamp(),
    });
  }
}