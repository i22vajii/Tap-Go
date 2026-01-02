import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:Tap_Go/screens/client/views/active_queue_view.dart';
import 'package:Tap_Go/screens/client/views/offers_list_view.dart';
import 'package:Tap_Go/screens/client/views/parking_ticket_view.dart';
import 'package:Tap_Go/services/queue_service.dart';
import 'package:Tap_Go/services/offers_service.dart';
import 'package:Tap_Go/services/parking_service.dart';

// Generación de Mocks
@GenerateMocks([
  QueueService, 
  OffersService,
  ParkingService, 
  DocumentSnapshot,
  FlutterLocalNotificationsPlugin 
])
import 'clients_widgets_test.mocks.dart'; 

void main() {
  late MockQueueService mockQueueService;
  late MockOffersService mockOffersService;
  late MockParkingService mockParkingService; 
  late MockDocumentSnapshot<Object?> mockQueueDoc;
  late MockFlutterLocalNotificationsPlugin mockNotificationsPlugin;

  setUp(() {
    mockQueueService = MockQueueService();
    mockOffersService = MockOffersService();
    mockParkingService = MockParkingService();
    mockQueueDoc = MockDocumentSnapshot();
    mockNotificationsPlugin = MockFlutterLocalNotificationsPlugin();

    // --- FIX PARA LOCAL NOTIFICATIONS ---
    when(mockNotificationsPlugin.initialize(any, 
        onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse'),
        onDidReceiveBackgroundNotificationResponse: anyNamed('onDidReceiveBackgroundNotificationResponse')
    )).thenAnswer((_) async => true);
    
    // Configuración para que no pida permisos ni falle en test
    when(mockNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
        .thenReturn(null);
    when(mockNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>())
        .thenReturn(null);

    when(mockNotificationsPlugin.show(any, any, any, any, payload: anyNamed('payload')))
        .thenAnswer((_) async {});

    // --- FIX PARA NFC MANAGER ---
    // Interceptamos el canal de NFC para que no de error "MissingPluginException"
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/nfc_manager'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isAvailable') return false; 
        return null;
      },
    );
  });

  group('ActiveQueueView Tests', () {
    testWidgets('Muestra estado "EN ESPERA" cuando hay gente delante', (WidgetTester tester) async {
      const queueId = 'shop-1';
      const myTicket = 10;

      when(mockQueueDoc.exists).thenReturn(true);
      when(mockQueueService.getQueueStream(queueId))
          .thenAnswer((_) => Stream.value(mockQueueDoc));

      when(mockQueueService.calculateMetrics(any, myTicket)).thenReturn(
        QueueMetrics(
          currentServing: 5,
          peopleAhead: 5,
          isMyTurn: false,
          formattedWaitTime: '10 min',
        )
      );

      await tester.pumpWidget(MaterialApp(
        home: ActiveQueueView(
          onLeave: () {},
          queueId: queueId,
          myTicketNumber: myTicket,
          service: mockQueueService,
          notificationPlugin: mockNotificationsPlugin,
        ),
      ));

      await tester.pump(); 

      expect(find.text('EN ESPERA'), findsOneWidget);
    });
  });

  group('OffersListView Tests', () {
    testWidgets('Muestra lista de ofertas correctamente', (WidgetTester tester) async {
      final oferta1 = OfferModel(
          id: '1', title: '2x1 Cerveza', description: 'Todo el dia', code: 'BEER', isActive: true);
      
      when(mockOffersService.getOffersByShop('shop-1'))
          .thenAnswer((_) => Stream.value([oferta1]));

      await tester.pumpWidget(MaterialApp(
        home: OffersListView(
          service: mockOffersService,
          initialShopId: 'shop-1',
        ),
      ));

      await tester.pump();

      expect(find.text('2x1 Cerveza'), findsOneWidget);
    });
  });

  group('ParkingTicketView Tests', () {
    testWidgets('Muestra escáner si no hay ticket activo', (WidgetTester tester) async {
      // 1. Arrange: No hay ticket activo
      when(mockParkingService.findActiveTicketId()).thenAnswer((_) async => null);

      // 2. Build
      await tester.pumpWidget(MaterialApp(
        home: ParkingTicketView(service: mockParkingService),
      ));

      // Esperar a que termine _isInitializing
      await tester.pump(); 

      // 3. Assert
      expect(find.text("Mi Parking"), findsOneWidget); 
    });

    testWidgets('Muestra ticket activo si el servicio devuelve un ID', (WidgetTester tester) async {
      // 1. Arrange: Hay ticket
      const ticketId = 'ticket-123';
      when(mockParkingService.findActiveTicketId()).thenAnswer((_) async => ticketId);

      final ticketObj = ParkingTicket(
        id: ticketId, 
        shopId: 'Parking Central', 
        entryTime: DateTime.now(), 
        status: 'pendiente', 
        isValidated: false, 
        isFinished: false
      );
      
      when(mockParkingService.getTicketStream(ticketId))
          .thenAnswer((_) => Stream.value(ticketObj));

      // 2. Build
      await tester.pumpWidget(MaterialApp(
        home: ParkingTicketView(service: mockParkingService),
      ));

      // PRIMER PUMP: Resuelve el Future de _buscarTicketActivo (initState)
      await tester.pump(); 
      
      // SEGUNDO PUMP: Permite que el StreamBuilder reciba el dato y pinte la UI final
      await tester.pump(); 

      // 3. Assert
      expect(find.text("TICKET ACTIVO"), findsOneWidget);
    });
  });
}