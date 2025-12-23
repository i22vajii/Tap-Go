import 'package:cloud_firestore/cloud_firestore.dart';

class OffersService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String collection = 'ofertas';

  // Obtener stream de ofertas activas en tiempo real
  Stream<QuerySnapshot> getActiveOffersStream() {
    return _db
        .collection(collection)
        .where('activa', isEqualTo: true)
        // Opcional: Ordenar por prioridad o fecha si tienes esos campos
        // .orderBy('prioridad', descending: true) 
        .snapshots();
  }
}