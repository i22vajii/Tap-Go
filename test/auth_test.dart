import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Tap_Go/services/auth_service.dart'; 

// Esta anotación genera el archivo auth_test.mocks.dart
@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  UserCredential,
  User,
  DocumentSnapshot,
  CollectionReference,
  DocumentReference
])
import 'auth_test.mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late AuthService authService;

  // Mocks auxiliares para la cadena de datos
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;
  late MockDocumentSnapshot<Map<String, dynamic>> mockSnapshot;
  late MockCollectionReference<Map<String, dynamic>> mockCollectionReference;
  late MockDocumentReference<Map<String, dynamic>> mockDocumentReference;

  setUp(() {
    // 1. Inicializar Mocks
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();
    mockSnapshot = MockDocumentSnapshot();
    mockCollectionReference = MockCollectionReference();
    mockDocumentReference = MockDocumentReference();

    // 2. Inyectar Mocks en el servicio
    authService = AuthService(auth: mockAuth, firestore: mockFirestore);

    // 3. Configuración COMÚN para evitar repetir código
    // Cuando pidan el usuario del credencial, devolvemos nuestro usuario mock
    when(mockUserCredential.user).thenReturn(mockUser);
    // Simulamos un UID
    when(mockUser.uid).thenReturn('test-uid-123');

    // Configuración de la cadena de Firestore:
    // firestore.collection('owners') -> devuelve referencia colección
    when(mockFirestore.collection('owners')).thenReturn(mockCollectionReference);
    // collection.doc(uid) -> devuelve referencia documento
    when(mockCollectionReference.doc(any)).thenReturn(mockDocumentReference);
    // document.get() -> devuelve el snapshot (lo configuramos en cada test según convenga)
    when(mockDocumentReference.get()).thenAnswer((_) async => mockSnapshot);
  });

  group('Pruebas de AuthService - LoginOwner', () {
    
    test('Debe loguear si las credenciales son correctas y existe en owners', () async {
      // ARRANGE
      // 1. Login exitoso en Auth
      when(mockAuth.signInWithEmailAndPassword(
        email: 'admin@test.com', 
        password: '123'
      )).thenAnswer((_) async => mockUserCredential);

      // 2. Existe en Firestore (owners)
      when(mockSnapshot.exists).thenReturn(true);

      // ACT
      final result = await authService.loginOwner('admin@test.com', '123');

      // ASSERT
      expect(result, isA<User>());
      expect(result?.uid, 'test-uid-123');
      // Verificamos que NO se llamó a cerrar sesión
      verifyNever(mockAuth.signOut());
    });

    test('Debe lanzar error "not-owner" y CERRAR SESIÓN si no está en owners', () async {
      // ARRANGE
      // 1. Login exitoso en Auth
      when(mockAuth.signInWithEmailAndPassword(
        email: 'intruso@test.com', 
        password: '123'
      )).thenAnswer((_) async => mockUserCredential);

      // 2. NO existe en Firestore (owners)
      when(mockSnapshot.exists).thenReturn(false);

      when(mockAuth.signOut()).thenAnswer((_) async {});

      // ACT & ASSERT
      try {
        await authService.loginOwner('intruso@test.com', '123');
        fail('Debería haber lanzado una excepción FirebaseAuthException');
      } on FirebaseAuthException catch (e) {
        // Verificamos que es el error correcto
        expect(e.code, 'not-owner');

        // VERIFY
        // Ahora sí detectará la llamada porque el mock sabe responder a ella
        verify(mockAuth.signOut()).called(1);
      }
    });
  });
}