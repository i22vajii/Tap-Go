import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Ajusta la ruta a tu proyecto
import 'package:Tap_Go/services/offers_service.dart';

// Generamos los mocks necesarios.
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
import 'offers_test.mocks.dart';

void main() {
  late OffersService offersService;

  // Mocks
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockUser mockUser;
  
  // Mocks de Firestore
  late MockCollectionReference<Map<String, dynamic>> mockCollectionRef;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;
  late MockQuery<Map<String, dynamic>> mockQuery;
  late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
  late MockQueryDocumentSnapshot<Map<String, dynamic>> mockQueryDocSnapshot;
  late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnapshot;

  setUp(() {
    // 1. Inicializar Mocks
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockUser = MockUser();
    mockCollectionRef = MockCollectionReference();
    mockDocRef = MockDocumentReference();
    mockQuery = MockQuery();
    mockQuerySnapshot = MockQuerySnapshot();
    mockQueryDocSnapshot = MockQueryDocumentSnapshot();
    mockDocSnapshot = MockDocumentSnapshot();

    // 2. Inyectar dependencias
    offersService = OffersService(db: mockFirestore, auth: mockAuth);

    // 3. Configuración Base de Firestore
    
    // Usamos el string explícito 'ofertas' para asegurar que Mockito lo detecte
    when(mockFirestore.collection('ofertas')).thenReturn(mockCollectionRef);
    // Dejamos el genérico por si acaso, pero el de arriba es el importante
    when(mockFirestore.collection(any)).thenReturn(mockCollectionRef);

    when(mockCollectionRef.doc(any)).thenReturn(mockDocRef);
    
    // Configurar el chaining de 'where'
    // IMPORTANTE: Usar anyNamed para los parámetros nombrados si usamos matchers
    when(mockCollectionRef.where(any, isEqualTo: anyNamed('isEqualTo')))
        .thenReturn(mockQuery);
    when(mockQuery.where(any, isEqualTo: anyNamed('isEqualTo')))
        .thenReturn(mockQuery);

    // Configurar retornos vacíos para operaciones de escritura
    when(mockCollectionRef.add(any)).thenAnswer((_) async => mockDocRef);
    when(mockDocRef.update(any)).thenAnswer((_) async {});
    when(mockDocRef.delete()).thenAnswer((_) async {});
  });

  group('1. Lógica de Parsing (Synchronous)', () {
    test('cleanNfcPayload - Elimina los primeros 2 caracteres si es largo', () {
      expect(offersService.cleanNfcPayload('enHola'), 'Hola');
    });

    test('cleanNfcPayload - Devuelve igual si es corto', () {
      expect(offersService.cleanNfcPayload('Hi'), 'Hi');
    });

    test('extractShopId - Extrae ID si tiene prefijo', () {
      expect(offersService.extractShopId('ofertas_tienda123'), 'tienda123');
    });

    test('extractShopId - Devuelve rawCode si no tiene prefijo', () {
      expect(offersService.extractShopId('tienda123'), 'tienda123');
    });
  });

  group('2. Lógica de Admin (Get ID)', () {
    test('getAdminShopId - Éxito con shopID', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('uid-admin');
      when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(mockDocSnapshot.exists).thenReturn(true);
      when(mockDocSnapshot.data()).thenReturn({'shopID': 'shop-ABC'});

      final result = await offersService.getAdminShopId();
      expect(result, 'shop-ABC');
    });

    test('getAdminShopId - Error si no hay usuario', () {
      when(mockAuth.currentUser).thenReturn(null);
      expect(() => offersService.getAdminShopId(), throwsA(contains('No hay sesión')));
    });
  });

  group('3. Lectura de Ofertas (Streams)', () {
    test('getOffersByShop (Cliente) - Filtra activas y devuelve lista', () async {
      // Arrange
      when(mockQueryDocSnapshot.data()).thenReturn({
        'titulo': '2x1',
        'codigo': 'CODE2X1',
        'activa': true,
        'descripcion': 'Desc',
      });
      when(mockQueryDocSnapshot.id).thenReturn('doc-id-1');
      when(mockQuerySnapshot.docs).thenReturn([mockQueryDocSnapshot]);

      // Configuramos el Stream
      when(mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockQuerySnapshot));

      // Act
      final stream = offersService.getOffersByShop('shop-1');

      // Assert
      // Usamos solo 'await stream.first' para verificar el contenido.
      final offers = await stream.first;
      
      expect(offers, isA<List<OfferModel>>());
      expect(offers.length, 1);
      expect(offers.first.title, '2x1');
      expect(offers.first.isActive, true);

      // Verificamos filtros
      verify(mockCollectionRef.where('shopID', isEqualTo: 'shop-1')).called(1);
      verify(mockQuery.where('activa', isEqualTo: true)).called(1);
    });

    test('getAdminOffersStream (Admin) - Trae todo sin filtrar por activa', () async {
      // Arrange
      when(mockQuerySnapshot.docs).thenReturn([]); 
      when(mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockQuerySnapshot));

      // Act
      final stream = offersService.getAdminOffersStream('shop-1');
      final result = await stream.first;

      // Assert
      expect(result, isEmpty);
      
      verify(mockCollectionRef.where('shopID', isEqualTo: 'shop-1')).called(1);
      
      // Usamos anyNamed('isEqualTo') porque 'isEqualTo' es un argumento nombrado
      verifyNever(mockQuery.where('activa', isEqualTo: anyNamed('isEqualTo')));
    });
  });

  group('4. Escritura (Create, Update, Delete)', () {
    test('createOffer - Añade documento con Timestamp', () async {
      // Act
      await offersService.createOffer(
        shopId: 'shop-1',
        title: 'Promo Verano',
        code: 'SUMMER',
        isActive: true,
      );

      // Assert
      // Aquí funcionará porque en setUp pusimos when(collection('ofertas'))
      verify(mockCollectionRef.add(argThat(
        allOf(
          containsPair('shopID', 'shop-1'),
          containsPair('titulo', 'Promo Verano'),
          containsPair('codigo', 'SUMMER'),
          containsPair('activa', true),
          contains('createdAt'), 
        ),
      ))).called(1);
    });

    test('toggleOfferStatus - Actualiza el booleano', () async {
      // Act
      await offersService.toggleOfferStatus('offer-id-1', false);

      // Assert
      verify(mockCollectionRef.doc('offer-id-1')).called(1);
      verify(mockDocRef.update({'activa': false})).called(1);
    });

    test('deleteOffer - Borra el documento', () async {
      // Act
      await offersService.deleteOffer('offer-id-X');

      // Assert
      verify(mockCollectionRef.doc('offer-id-X')).called(1);
      verify(mockDocRef.delete()).called(1);
    });
  });
}