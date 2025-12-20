import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Método para iniciar sesión solo si es Dueño
  Future<User?> loginOwner(String email, String password) async {
    try {
      // 1. Intentar loguearse en Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // 2. Verificar si existe en la colección 'owners'
        DocumentSnapshot ownerDoc = await _firestore
            .collection('owners') // Tu colección de dueños
            .doc(user.uid)
            .get();

        if (ownerDoc.exists) {
          // ES UN DUEÑO: Éxito
          return user;
        } else {
          // NO ES DUEÑO (Es un cliente o intruso): Cerrar sesión y lanzar error
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'not-owner',
            message: 'Este usuario no tiene perfil de administrador.',
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      // Relanzar el error para manejarlo en la UI
      rethrow;
    }
    return null;
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }
}