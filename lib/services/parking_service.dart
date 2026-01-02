import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==========================================
// 1. MODELOS DE DATOS (DTOs)
// ==========================================

/// Modelo para representar un ticket en la UI (Cliente y Admin)
class ParkingTicket {
  final String id;
  final String shopId;
  final DateTime entryTime;
  final String status; // 'pendiente', 'validado', 'finalizado'
  final bool isValidated;
  final bool isFinished;

  ParkingTicket({
    required this.id,
    required this.shopId,
    required this.entryTime,
    required this.status,
    required this.isValidated,
    required this.isFinished,
  });

  factory ParkingTicket.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    final String status = data['estado'] ?? 'pendiente';
    final Timestamp? entryTs = data['entrada'];

    return ParkingTicket(
      id: doc.id,
      shopId: data['shopID'] ?? 'Desconocido',
      entryTime: entryTs?.toDate() ?? DateTime.now(),
      status: status,
      isValidated: status == 'validado',
      isFinished: status == 'finalizado',
    );
  }

  /// Helper para mostrar la duración formateada (ej: "2h 15m")
  String get formattedDuration {
    final duration = DateTime.now().difference(entryTime);
    return "${duration.inHours}h ${duration.inMinutes.remainder(60)}m";
  }
}

/// Modelo específico para devolver los cálculos al Admin antes de cobrar
class TicketCalculation {
  final String ticketId;
  final Duration duration;
  final double totalPrice;
  final String formattedTime;

  TicketCalculation({
    required this.ticketId,
    required this.duration,
    required this.totalPrice,
    required this.formattedTime,
  });
}

// ==========================================
// 2. SERVICIO PRINCIPAL
// ==========================================

class ParkingService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final String collection = 'tickets_parking';

  ParkingService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ---------------------------------------------------------
  // SECCIÓN A: UTILIDADES Y VALIDACIONES (Comunes)
  // ---------------------------------------------------------

  /// Limpia el payload NFC eliminando prefijos de idioma (ej: "en")
  String cleanNfcPayload(String rawText) {
    if (rawText.length > 2) {
      return rawText.substring(2);
    }
    return rawText;
  }

  /// Valida que el código sea de parking y extrae el ID de la tienda.
  /// Formato esperado: "parking_tienda_01"
  String validateAndExtractShopId(String rawCode) {
    final codigoLimpio = rawCode.trim();
    
    if (!codigoLimpio.startsWith('parking_')) {
      throw "Código inválido. No es un código de Parking.";
    }

    final shopId = codigoLimpio.replaceFirst('parking_', '');
    
    if (shopId.isEmpty) {
      throw "El código QR/NFC está vacío o mal formado.";
    }
    
    return shopId;
  }

  // ---------------------------------------------------------
  // SECCIÓN B: LÓGICA DEL CLIENTE (ParkingTicketView)
  // ---------------------------------------------------------

  /// 1. Buscar si el usuario ya tiene un ticket activo
  Future<String?> findActiveTicketId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      QuerySnapshot snapshot = await _db
          .collection(collection)
          .where('usuario_uid', isEqualTo: user.uid)
          .where('estado', whereIn: ['pendiente', 'validado']) // Tickets en curso
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 2. Obtener Stream del Ticket convertido a MODELO
  Stream<ParkingTicket> getTicketStream(String ticketId) {
    return _db.collection(collection).doc(ticketId).snapshots().map((doc) {
      if (!doc.exists) throw "El ticket ha sido eliminado o cerrado.";
      return ParkingTicket.fromSnapshot(doc);
    });
  }

  /// 3. ENTRADA (Check-in): Crea el ticket en la DB
  Future<String> checkIn(String rawCode) async {
    // Validamos y extraemos ID
    final shopId = validateAndExtractShopId(rawCode);

    final user = _auth.currentUser;
    final uid = user?.uid ?? 'usuario_invitado';

    DocumentReference ref = _db.collection(collection).doc(); 

    await ref.set({
      'usuario_uid': uid,
      'entrada': FieldValue.serverTimestamp(),
      'estado': 'pendiente', 
      'coste': 0.0,
      'shopID': shopId, 
    });

    return ref.id;
  }

  /// 4. SALIDA (Check-out): Finaliza el ticket (Solo si ya está validado/pagado o es demo)
  Future<void> checkOut(String ticketId) async {
    await _db.collection(collection).doc(ticketId).update({
      'estado': 'finalizado',
      'salida': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------
  // SECCIÓN C: LÓGICA DEL ADMIN (AdminParkingValidator)
  // ---------------------------------------------------------

  /// 1. Obtener ID de la tienda del Admin (Privado, uso interno)
  Future<String> _getAdminShopId() async {
    final user = _auth.currentUser;
    if (user == null) throw "No hay sesión de administrador activa.";

    final doc = await _db.collection('owners').doc(user.uid).get();
    if (!doc.exists) throw "No se encontró perfil de administrador.";

    final data = doc.data();
    final shopId = data?['shopID'] ?? data?['shop_ID'];

    if (shopId == null || shopId.toString().isEmpty) {
      throw "El administrador no tiene un Parking asignado.";
    }
    return shopId.toString();
  }

  /// 2. Verificar ticket y Calcular Precio
  /// Este método es el cerebro de la validación: chequea seguridad y matemáticas.
  Future<TicketCalculation> verifyAndCalculateTicket(String ticketId) async {
    // A. Seguridad: Obtener ShopID del Admin actual
    final String adminShopId = await _getAdminShopId();

    // B. Obtener Ticket de la DB
    final doc = await _db.collection(collection).doc(ticketId).get();
    if (!doc.exists) throw "Ticket no encontrado en la base de datos.";

    final ticket = ParkingTicket.fromSnapshot(doc);

    // C. Validaciones de Negocio
    if (ticket.shopId != adminShopId) {
      throw "⛔ ACCESO DENEGADO: Este ticket pertenece a otro parking (${ticket.shopId}).";
    }

    if (ticket.isValidated || ticket.isFinished) {
      throw "Este ticket YA fue validado o finalizado anteriormente.";
    }

    // D. Cálculos Matemáticos (Precios)
    final now = DateTime.now();
    final duration = now.difference(ticket.entryTime);
    
    // REGLA DE NEGOCIO: 0.05€/min, Mínimo 1.00€
    double price = (duration.inMinutes * 0.05);
    price = max(price, 1.0); // Nos aseguramos que el mínimo sea 1€

    return TicketCalculation(
      ticketId: ticketId,
      duration: duration,
      totalPrice: price,
      formattedTime: "${duration.inHours}h ${duration.inMinutes.remainder(60)}m",
    );
  }

  /// 3. Procesar el Pago (Escritura en DB)
  /// Cambia el estado a 'validado' para que el cliente pueda salir.
  Future<void> processPayment(String ticketId, double amount) async {
    final user = _auth.currentUser;
    
    await _db.collection(collection).doc(ticketId).update({
      'estado': 'validado',
      'coste': amount,
      'salida': FieldValue.serverTimestamp(), // Se marca la hora de pago/salida
      'validado_por': user?.uid,
    });
  }
}