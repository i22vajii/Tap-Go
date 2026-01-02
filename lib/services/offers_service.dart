import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- 1. MODELO DE DATOS (DTO) ---
class OfferModel {
  final String id;
  final String title;
  final String description; // Puede ser opcional en la creación, pero útil en lectura
  final String code;
  final bool isActive; // Nuevo campo necesario para el admin

  OfferModel({
    required this.id,
    required this.title,
    required this.description,
    required this.code,
    required this.isActive,
  });

  factory OfferModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return OfferModel(
      id: doc.id,
      title: data['titulo'] ?? "Sin título",
      description: data['descripcion'] ?? "",
      code: data['codigo'] ?? "---",
      isActive: data['activa'] ?? false,
    );
  }
}

// --- 2. SERVICIO ---
class OffersService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final String collection = 'ofertas';

  // Constructor que permite inyección de mocks
  OffersService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ==========================================
  // LÓGICA DE PARSING (Cliente)
  // ==========================================
  String cleanNfcPayload(String rawText) {
    if (rawText.length > 2) return rawText.substring(2);
    return rawText;
  }

  String extractShopId(String rawCode) {
    if (rawCode.contains('ofertas_')) return rawCode.split('ofertas_')[1];
    return rawCode;
  }

  // ==========================================
  // LÓGICA DE LECTURA (Cliente)
  // ==========================================
  Stream<List<OfferModel>> getOffersByShop(String shopId) {
    return _db
        .collection(collection)
        .where('shopID', isEqualTo: shopId)
        .where('activa', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => OfferModel.fromSnapshot(doc)).toList());
  }

  // ==========================================
  // LÓGICA DE ADMINISTRACIÓN (Admin)
  // ==========================================

  // 1. Obtener ID de la tienda del Admin
  Future<String> getAdminShopId() async {
    final user = _auth.currentUser;
    if (user == null) throw "No hay sesión activa";

    final doc = await _db.collection('owners').doc(user.uid).get();
    if (!doc.exists) throw "Usuario no registrado como dueño";

    final data = doc.data();
    // Soporte para ambos nombres de campo por seguridad
    final shopId = data?['shopID'] ?? data?['shop_ID'];

    if (shopId == null || shopId.toString().isEmpty) throw "Sin tienda asignada";
    return shopId.toString();
  }

  // 2. Stream de ofertas del Admin (Muestra activas e inactivas)
  Stream<List<OfferModel>> getAdminOffersStream(String shopId) {
    return _db
        .collection(collection)
        .where('shopID', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => OfferModel.fromSnapshot(doc)).toList());
  }

  // 3. Crear Oferta
  Future<void> createOffer({
    required String shopId,
    required String title,
    required String code,
    required bool isActive,
  }) async {
    await _db.collection(collection).add({
      'titulo': title,
      'codigo': code,
      'activa': isActive,
      'shopID': shopId,
      'descripcion': '', // Campo opcional
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 4. Actualizar estado (Visibilidad)
  Future<void> toggleOfferStatus(String offerId, bool newStatus) async {
    await _db.collection(collection).doc(offerId).update({'activa': newStatus});
  }

  // 5. Eliminar Oferta
  Future<void> deleteOffer(String offerId) async {
    await _db.collection(collection).doc(offerId).delete();
  }
}