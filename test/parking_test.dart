import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Tap_Go/services/parking_service.dart';

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
  QueryDocumentSnapshot
])
import 'parking_test.mocks.dart';

void main() {
  late ParkingService parkingService;

  // Mocks
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockUser mockUser;
  
  // Mocks de Firestore
  late MockCollectionReference<Map<String, dynamic>> mockCollectionRef;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;
  late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnapshot;
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
    mockQuery = MockQuery();
    mockQuerySnapshot = MockQuerySnapshot();
    mockQueryDocSnapshot = MockQueryDocumentSnapshot();

    // 2. Inyección
    parkingService = ParkingService(db: mockFirestore, auth: mockAuth);

    // 3. Configuración Base de Firestore
    when(mockFirestore.collection('tickets_parking')).thenReturn(mockCollectionRef);
    when(mockFirestore.collection('owners')).thenReturn(mockCollectionRef);
    when(mockFirestore.collection(any)).thenReturn(mockCollectionRef);

    when(mockCollectionRef.doc(any)).thenReturn(mockDocRef);
    when(mockCollectionRef.doc()).thenReturn(mockDocRef); 

    // Configurar updates y sets para que no fallen
    when(mockDocRef.set(any)).thenAnswer((_) async {});
    when(mockDocRef.update(any)).thenAnswer((_) async {});
  });

  group('1. Utilidades y Validaciones', () {
    test('cleanNfcPayload - Limpia prefijo', () {
      expect(parkingService.cleanNfcPayload('enCode123'), 'Code123');
      expect(parkingService.cleanNfcPayload('AB'), 'AB');
    });

    test('validateAndExtractShopId - Éxito', () {
      final res = parkingService.validateAndExtractShopId('parking_shop_01');
      expect(res, 'shop_01');
    });

    test('validateAndExtractShopId - Error si formato incorrecto', () {
      expect(() => parkingService.validateAndExtractShopId('tienda_normal'), throwsA(isA<String>()));
    });
  });

  group('2. Lógica del Cliente', () {
    test('findActiveTicketId - Devuelve ID si existe ticket pendiente', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('uid-user');

      when(mockCollectionRef.where('usuario_uid', isEqualTo: anyNamed('isEqualTo'))).thenReturn(mockQuery);
      when(mockQuery.where('estado', whereIn: anyNamed('whereIn'))).thenReturn(mockQuery);
      when(mockQuery.limit(1)).thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

      when(mockQuerySnapshot.docs).thenReturn([mockQueryDocSnapshot]);
      when(mockQueryDocSnapshot.id).thenReturn('ticket-activo-123');

      final result = await parkingService.findActiveTicketId();
      expect(result, 'ticket-activo-123');
    });

    test('checkIn - Crea documento con estado pendiente', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('uid-user');
      when(mockDocRef.id).thenReturn('new-ticket-id');

      final result = await parkingService.checkIn('parking_shop_A');

      expect(result, 'new-ticket-id');
      
      verify(mockDocRef.set(argThat(
        allOf(
          containsPair('usuario_uid', 'uid-user'),
          containsPair('shopID', 'shop_A'),
          containsPair('estado', 'pendiente'),
          contains('entrada'), 
        )
      ))).called(1);
    });

    test('checkOut - Finaliza el ticket', () async {
      await parkingService.checkOut('ticket-123');

      verify(mockDocRef.update(argThat(
        allOf(
          containsPair('estado', 'finalizado'),
          contains('salida')
        )
      ))).called(1);
    });
  });

  group('3. Lógica del Admin (Cálculos y Seguridad)', () {
    test('verifyAndCalculateTicket - Éxito: Calcula precio y valida tienda', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('admin-uid');
      
      final mockOwnerSnap = MockDocumentSnapshot<Map<String, dynamic>>();
      final mockTicketSnap = MockDocumentSnapshot<Map<String, dynamic>>();

      // Configuración Owner
      when(mockOwnerSnap.exists).thenReturn(true);
      when(mockOwnerSnap.data()).thenReturn({'shopID': 'shop_A'});

      // Configuración Ticket
      when(mockTicketSnap.exists).thenReturn(true);
      when(mockTicketSnap.id).thenReturn('ticket-123'); // ID necesario
      when(mockTicketSnap.data()).thenReturn({
        'shopID': 'shop_A', 
        'estado': 'pendiente',
        'entrada': Timestamp.fromDate(DateTime.now().subtract(Duration(minutes: 60))),
      });

      int callCount = 0;
      when(mockDocRef.get()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return mockOwnerSnap;
        return mockTicketSnap;
      });

      final calculo = await parkingService.verifyAndCalculateTicket('ticket-123');

      expect(calculo.totalPrice, closeTo(3.0, 0.01)); 
      expect(calculo.formattedTime, contains('1h'));
    });

    test('verifyAndCalculateTicket - Error de Seguridad (ShopID distinto)', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('admin-uid'); 

      final mockOwnerSnap = MockDocumentSnapshot<Map<String, dynamic>>();
      when(mockOwnerSnap.exists).thenReturn(true);
      when(mockOwnerSnap.data()).thenReturn({'shopID': 'shop_A'});

      final mockTicketSnap = MockDocumentSnapshot<Map<String, dynamic>>();
      when(mockTicketSnap.exists).thenReturn(true);
      
      when(mockTicketSnap.id).thenReturn('ticket-intruso'); 
      
      when(mockTicketSnap.data()).thenReturn({
        'shopID': 'shop_B', // ID distinto provoca el error esperado
        'estado': 'pendiente',
        'entrada': Timestamp.now(),
      });

      int callCount = 0;
      when(mockDocRef.get()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return mockOwnerSnap;
        return mockTicketSnap;
      });

      expect(
        () => parkingService.verifyAndCalculateTicket('ticket-123'),
        throwsA(contains('ACCESO DENEGADO')) 
      );
    });

    test('verifyAndCalculateTicket - Aplica precio mínimo (1.0€)', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('admin-uid');

      final mockOwnerSnap = MockDocumentSnapshot<Map<String, dynamic>>();
      when(mockOwnerSnap.exists).thenReturn(true);
      when(mockOwnerSnap.data()).thenReturn({'shopID': 'shop_A'});

      final mockTicketSnap = MockDocumentSnapshot<Map<String, dynamic>>();
      when(mockTicketSnap.exists).thenReturn(true);
      when(mockTicketSnap.id).thenReturn('ticket-min'); // ID necesario
      when(mockTicketSnap.data()).thenReturn({
        'shopID': 'shop_A',
        'estado': 'pendiente',
        'entrada': Timestamp.fromDate(DateTime.now().subtract(Duration(minutes: 5))),
      });

      int callCount = 0;
      when(mockDocRef.get()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return mockOwnerSnap;
        return mockTicketSnap;
      });

      final calculo = await parkingService.verifyAndCalculateTicket('ticket-min');

      expect(calculo.totalPrice, 1.0); 
    });
  });

  group('4. Pago', () {
    test('processPayment - Actualiza estado y coste', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('admin-uid');

      await parkingService.processPayment('ticket-123', 5.50);

      verify(mockDocRef.update(argThat(
        allOf(
          containsPair('estado', 'validado'),
          containsPair('coste', 5.50),
          containsPair('validado_por', 'admin-uid'),
          contains('salida'),
        )
      ))).called(1);
    });
  });
}