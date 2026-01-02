import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Ajusta la ruta a tu proyecto
import 'package:Tap_Go/services/stats_service.dart';

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  User,
  DocumentSnapshot,
  CollectionReference,
  DocumentReference,
  Query,
  QuerySnapshot,
  QueryDocumentSnapshot
])
import 'stats_test.mocks.dart';

void main() {
  late StatsService statsService;

  // Mocks
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockUser mockUser;
  
  // Mocks Firestore
  late MockCollectionReference<Map<String, dynamic>> mockCollectionRef;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;
  late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnapshot;
  late MockQuery<Map<String, dynamic>> mockQuery;
  late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
  late MockQueryDocumentSnapshot<Map<String, dynamic>> mockQueryDocSnapshot;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockUser = MockUser();
    mockCollectionRef = MockCollectionReference();
    mockDocRef = MockDocumentReference();
    mockDocSnapshot = MockDocumentSnapshot();
    mockQuery = MockQuery();
    mockQuerySnapshot = MockQuerySnapshot();
    mockQueryDocSnapshot = MockQueryDocumentSnapshot();

    statsService = StatsService(db: mockFirestore, auth: mockAuth);

    // Configuración Base
    when(mockFirestore.collection(any)).thenReturn(mockCollectionRef);
    when(mockCollectionRef.doc(any)).thenReturn(mockDocRef);
    
    // Configuración de Queries encadenadas (Fluent Interface)
    // collection.where -> query
    when(mockCollectionRef.where(any, isEqualTo: anyNamed('isEqualTo'))).thenReturn(mockQuery);
    when(mockCollectionRef.where(any, isGreaterThan: anyNamed('isGreaterThan'))).thenReturn(mockQuery);
    
    // query.where -> query
    when(mockQuery.where(any, isEqualTo: anyNamed('isEqualTo'))).thenReturn(mockQuery);
    when(mockQuery.where(any, isGreaterThan: anyNamed('isGreaterThan'))).thenReturn(mockQuery);
    
    // query.orderBy -> query
    when(mockQuery.orderBy(any, descending: anyNamed('descending'))).thenReturn(mockQuery);
  });

  group('1. Obtención de ShopID', () {
    test('getCurrentUserShopId - Retorna ID si existe', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('uid-123');
      when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(mockDocSnapshot.exists).thenReturn(true);
      when(mockDocSnapshot.data()).thenReturn({'shopID': 'shop-A'});

      final result = await statsService.getCurrentUserShopId();
      expect(result, 'shop-A');
    });

    test('getCurrentUserShopId - Retorna null si no hay user', () async {
      when(mockAuth.currentUser).thenReturn(null);
      final result = await statsService.getCurrentUserShopId();
      expect(result, null);
    });
  });

  group('2. KPIs de la Cola (getQueueKPIs)', () {
    test('Calcula waiting y avgTime correctamente', () async {
      // Arrange
      when(mockDocSnapshot.exists).thenReturn(true);
      // Simulamos datos crudos
      when(mockDocSnapshot.data()).thenReturn({
        'current_number': 10,
        'last_issued_number': 15, // Waiting = 5
        'served_count': 2,
        'total_service_seconds': 250, // Avg = 125s -> 2m 5s
      });
      when(mockDocRef.snapshots()).thenAnswer((_) => Stream.value(mockDocSnapshot));

      // Act
      final stream = statsService.getQueueKPIs('shop-A');
      final result = await stream.first;

      // Assert
      expect(result['waiting'], '5');
      expect(result['avgTime'], '2m 5s');
      expect(result['servedCount'], '2');
    });
  });

  group('3. Tasa de Abandono (getAbandonmentRate)', () {
    test('Calcula % de perdidos correctamente', () async {
      // Arrange: Crear lista de docs simulados
      final doc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      final doc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      final doc3 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      final doc4 = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      // Simulamos el operador []
      when(doc1['status']).thenReturn('served');
      when(doc2['status']).thenReturn('cancelled'); // Perdido
      when(doc3['status']).thenReturn('no-show');   // Perdido
      when(doc4['status']).thenReturn('waiting');

      when(mockQuerySnapshot.docs).thenReturn([doc1, doc2, doc3, doc4]);
      when(mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockQuerySnapshot));

      // Act
      final stream = statsService.getAbandonmentRate('shop-A');
      final result = await stream.first;

      // Assert
      // Total: 4, Lost: 2 -> Rate: 50%
      expect(result['total'], 4);
      expect(result['lost'], 2);
      expect(result['rate'], 50.0);
      expect(result['isBad'], true); // > 15%
    });
  });

  group('4. Horas Punta (getPeakHours)', () {
    test('Agrupa tickets por hora', () async {
      // Arrange
      final docA = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      final docB = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      // Creamos timestamps fijos (ej: 10:00 AM)
      final date10AM = DateTime(2023, 1, 1, 10, 30);
      
      when(docA.data()).thenReturn({'timestamp': Timestamp.fromDate(date10AM)});
      when(docB.data()).thenReturn({'timestamp': Timestamp.fromDate(date10AM)});

      when(mockQuerySnapshot.docs).thenReturn([docA, docB]);
      when(mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockQuerySnapshot));

      // Act
      final stream = statsService.getPeakHours('shop-A');
      final result = await stream.first;

      // Assert
      expect(result[10], 2.0); // A las 10h hay 2 tickets
      expect(result[12], 0.0); // A las 12h hay 0
    });
  });

  group('5. Estadísticas de Ofertas (getOfferStats)', () {
    test('Cuenta activas e inactivas', () async {
      final doc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      final doc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      // Simulamos el acceso con []
      when(doc1['activa']).thenReturn(true);
      when(doc2['activa']).thenReturn(false);

      when(mockQuerySnapshot.docs).thenReturn([doc1, doc2]);
      when(mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockQuerySnapshot));

      final stream = statsService.getOfferStats('shop-A');
      final result = await stream.first;

      expect(result['activas'], 1);
      expect(result['inactivas'], 1);
      expect(result['total'], 2);
    });
  });

  group('6. Tendencia Semanal (getWeeklyTrend)', () {
    test('Mapea tickets a los últimos 7 días', () async {
      // Arrange
      final now = DateTime.now();
      
      // Creamos docs para: "Hoy" (idx 6), "Ayer" (idx 5), "Hace 8 días" (fuera de rango)
      final docToday = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      final docYesterday = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      
      // Configurar timestamps
      when(docToday['timestamp']).thenReturn(Timestamp.fromDate(now));
      when(docYesterday['timestamp']).thenReturn(Timestamp.fromDate(now.subtract(Duration(days: 1))));

      // Nota: El servicio filtra por 'isGreaterThan: 7 days ago' en la query,
      // pero aquí simulamos lo que devuelve esa query.
      when(mockQuerySnapshot.docs).thenReturn([docToday, docYesterday]);
      
      // Cadena: collection -> where(queue) -> where(time) -> orderBy -> snapshots
      // Ya configuramos los returns en el setUp para que todos devuelvan mockQuery
      when(mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockQuerySnapshot));

      // Act
      final stream = statsService.getWeeklyTrend('shop-A');
      final result = await stream.first;

      // Assert
      // El array tiene 7 posiciones [Día-6, Día-5, ..., Ayer, Hoy]
      // Hoy está en index 6
      // Ayer está en index 5
      expect(result.length, 7);
      expect(result[6], 1.0, reason: "Debe haber 1 ticket hoy");
      expect(result[5], 1.0, reason: "Debe haber 1 ticket ayer");
      expect(result[0], 0.0, reason: "No hay tickets hace 6 días");
    });
  });
}