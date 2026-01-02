import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Tap_Go/services/queue_service.dart';

// Generación de Mocks
@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  User,
  DocumentSnapshot,
  CollectionReference,
  DocumentReference,
  Query,
  QuerySnapshot,
  QueryDocumentSnapshot,
  Transaction 
])
import 'queue_test.mocks.dart';

void main() {
  late QueueService queueService;
  
  // Mocks Principales
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockUser mockUser;
  
  // Mocks de Firestore Helpers
  late MockCollectionReference<Map<String, dynamic>> mockCollectionRef;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;
  late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnapshot;
  late MockTransaction mockTransaction;
  late MockQuery<Map<String, dynamic>> mockQuery;
  late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
  late MockQueryDocumentSnapshot<Map<String, dynamic>> mockQueryDocSnapshot;

  setUp(() {
    // 1. Inicialización
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockUser = MockUser();
    mockCollectionRef = MockCollectionReference();
    mockDocRef = MockDocumentReference();
    mockDocSnapshot = MockDocumentSnapshot();
    mockTransaction = MockTransaction();
    mockQuery = MockQuery();
    mockQuerySnapshot = MockQuerySnapshot();
    mockQueryDocSnapshot = MockQueryDocumentSnapshot();

    // 2. Inyección de dependencias
    queueService = QueueService(auth: mockAuth, firestore: mockFirestore);

    // --- CONFIGURACIÓN BASE DE FIRESTORE ---
    when(mockFirestore.collection(any)).thenReturn(mockCollectionRef);
    when(mockCollectionRef.doc(any)).thenReturn(mockDocRef);
    // Para casos donde se genera ID automático: collection.doc()
    when(mockCollectionRef.doc()).thenReturn(mockDocRef); 
    
    // --- SOLUCIÓN ERROR MISSING STUB ---
    // Configuramos los métodos de escritura de la transacción para que no fallen
    // y devuelvan la propia transacción (fluent interface)
    when(mockTransaction.update(any, any)).thenReturn(mockTransaction);
    when(mockTransaction.set(any, any)).thenReturn(mockTransaction);

    // --- TRUCO MAESTRO PARA TRANSACCIONES ---
    // Ejecutamos inmediatamente la función que se pasa a runTransaction
    when(mockFirestore.runTransaction(any)).thenAnswer((invocation) {
      final Function(Transaction) updateFunction = invocation.positionalArguments[0];
      return updateFunction(mockTransaction);
    });
  });

  group('1. Pruebas de Dueño (Owner)', () {
    test('getOwnerShopId - Éxito', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('uid-123');
      
      when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(mockDocSnapshot.exists).thenReturn(true);
      when(mockDocSnapshot.data()).thenReturn({'shopID': 'shop-A'});

      final result = await queueService.getOwnerShopId();

      expect(result, 'shop-A');
    });

    test('getOwnerShopId - Falla si no hay usuario', () {
      when(mockAuth.currentUser).thenReturn(null);
      expect(() => queueService.getOwnerShopId(), throwsA(contains('No hay sesión')));
    });

    test('initializeQueue - Crea documento con valores iniciales', () async {
      await queueService.initializeQueue('shop-A');

      // Usamos argThat para validar el mapa sin chocar con el Timestamp
      verify(mockDocRef.set(argThat(
        allOf(
          containsPair('current_number', 0),
          containsPair('last_issued_number', 0),
          containsPair('served_count', 0),
          containsPair('total_service_seconds', 0),
          contains('last_call_time'), // Solo verificamos que la key exista
        ),
      ))).called(1);
    });
  });

  group('2. Pruebas de Lógica (Cálculos locales)', () {
    test('calculateMetrics - Calcula tiempo estimado correctamente', () {
      when(mockDocSnapshot.data()).thenReturn({
        'current_number': 5,
        'total_service_seconds': 600, 
        'served_count': 3, 
      });

      // Ticket 7, atendiendo al 5 -> 2 personas delante
      final metrics = queueService.calculateMetrics(mockDocSnapshot, 7);

      expect(metrics.peopleAhead, 2);
      expect(metrics.isMyTurn, false);
      expect(metrics.formattedWaitTime, contains('min')); // Verificamos formato básico
    });
  });

  group('3. Pruebas de Transacciones (Complejas)', () {
    
    test('joinQueue - Genera ticket y actualiza cola', () async {
      const shopId = 'shop-1';
      const userId = 'user-1';

      // Configurar lectura DENTRO de la transacción
      when(mockTransaction.get(mockDocRef)).thenAnswer((_) async => mockDocSnapshot);
      when(mockDocSnapshot.exists).thenReturn(true);
      when(mockDocSnapshot.get('last_issued_number')).thenReturn(10); 

      // Act
      final newTicket = await queueService.joinQueue(shopId, userId);

      // Assert
      expect(newTicket, 11);

      // Verificar actualización de la cola
      verify(mockTransaction.update(mockDocRef, {
        'last_issued_number': 11
      })).called(1);

      // Verificar creación del ticket
      verify(mockTransaction.set(any, argThat(containsPair('ticket_number', 11)))).called(1);
    });

    test('advanceQueueSmart - Avanza turno y cierra ticket anterior', () async {
      // 1. Configurar lectura de la cola
      when(mockTransaction.get(mockDocRef)).thenAnswer((_) async => mockDocSnapshot);
      when(mockDocSnapshot.exists).thenReturn(true);
      
      // Datos: Se está atendiendo al 5, hay gente esperando (last=6)
      when(mockDocSnapshot.get('current_number')).thenReturn(5);
      when(mockDocSnapshot.get('last_issued_number')).thenReturn(6);
      when(mockDocSnapshot.get('served_count')).thenReturn(10);
      when(mockDocSnapshot.get('total_service_seconds')).thenReturn(1000);
      
      final now = Timestamp.now();
      when(mockDocSnapshot.data()).thenReturn({'last_call_time': now}); 

      // 2. Configurar búsqueda del ticket actual (para cerrarlo)
      when(mockCollectionRef.where(any, isEqualTo: anyNamed('isEqualTo'))).thenReturn(mockQuery);
      when(mockQuery.where(any, isEqualTo: anyNamed('isEqualTo'))).thenReturn(mockQuery);
      when(mockQuery.limit(1)).thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
      
      when(mockQuerySnapshot.docs).thenReturn([mockQueryDocSnapshot]);
      when(mockQueryDocSnapshot.reference).thenReturn(mockDocRef); 

      // Act
      await queueService.advanceQueueSmart('shop-1');

      // Assert
      // 1. Verificar que cierra el ticket (status: served y closed_at existe)
      verify(mockTransaction.update(mockDocRef, argThat(
        allOf(
          containsPair('status', 'served'),
          contains('closed_at')
        )
      ))).called(1);

      // 2. Verificar que avanza la cola (current_number pasa de 5 a 6)
      verify(mockTransaction.update(mockDocRef, argThat(
        containsPair('current_number', 6)
      ))).called(1);
    });
  });
}