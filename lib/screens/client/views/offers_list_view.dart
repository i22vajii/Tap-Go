import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import '../../../config/app_colors.dart';
import '../../../services/offers_service.dart';
import '../../common/qr_scanner_screen.dart';

class OffersListView extends StatefulWidget {
  const OffersListView({super.key});

  @override
  State<OffersListView> createState() => _OffersListViewState();
}

class _OffersListViewState extends State<OffersListView> {
  // Estado de la tienda seleccionada (null = modo escáner)
  String? _currentShopId;
  
  // Variables de UI para el escáner
  bool _isScanningNfc = false;
  bool _isLoading = false;

  // Instancia del servicio (aunque haremos una query directa para filtrar)
  final OffersService _offersService = OffersService();

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  // --- LÓGICA DE PROCESAMIENTO ---

  void _procesarCodigo(String rawCode) {
    // Lógica solicitada: "si contiene 'ofertas_tienda_01', shopId es 'tienda_01'"
    String shopId = rawCode;
    
    if (rawCode.contains('ofertas_')) {
      // Extraemos lo que hay después de 'ofertas_'
      shopId = rawCode.split('ofertas_')[1];
    } else {
      // Opcional: Si el código no tiene el formato esperado, avisamos o lo usamos tal cual
      // Para este ejemplo, asumimos que si no tiene prefijo, es el ID directo
    }

    setState(() {
      _currentShopId = shopId;
      _isLoading = false;
      _isScanningNfc = false;
    });
  }

  // --- LÓGICA DE ESCANEO (NFC y QR) ---

  void _startNfcScan() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      _showError("NFC no disponible o desactivado.");
      return;
    }

    setState(() => _isScanningNfc = true);

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) throw 'No es un tag NDEF';
            final ndefMessage = ndef.cachedMessage;
            if (ndefMessage == null) throw 'Etiqueta vacía';

            final record = ndefMessage.records.first;
            final payload = List<int>.from(record.payload);
            String textoLeido = utf8.decode(payload.sublist(1));

            // Limpieza estándar de prefijo de idioma NDEF (ej: "en...")
            if (textoLeido.length > 2) textoLeido = textoLeido.substring(2);

            await NfcManager.instance.stopSession();
            
            if (mounted) {
              _procesarCodigo(textoLeido);
            }
          } catch (e) {
            await NfcManager.instance.stopSession();
            if (mounted) {
              setState(() => _isScanningNfc = false);
              _showError("Error leyendo etiqueta NFC.");
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isScanningNfc = false);
        _showError("Error NFC: $e");
      }
    }
  }

  void _startQrScan() async {
    final codigo = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );

    if (codigo != null && codigo is String) {
      _procesarCodigo(codigo);
    }
  }

  void _resetView() {
    setState(() {
      _currentShopId = null;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentShopId == null ? "Buscador de Ofertas" : "Ofertas: $_currentShopId"),
        actions: [
          if (_currentShopId != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _resetView,
              tooltip: "Cerrar tienda",
            )
        ],
      ),
      backgroundColor: AppColors.grisHielo,
      body: _currentShopId == null 
          ? _buildScannerView()
          : _buildOffersList(_currentShopId!),
    );
  }

  // --- VISTA 1: ESCÁNER (Similar al Parking) ---
  
  Widget _buildScannerView() {
    String nfcText = _isScanningNfc ? "ACERCA EL MÓVIL..." : "ESCANEAR ETIQUETA TIENDA";
    IconData nfcIcon = _isScanningNfc ? Icons.wifi_tethering : Icons.nfc;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isScanningNfc ? AppColors.turquesaVivo.withOpacity(0.1) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: _isScanningNfc ? [] : [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
                ]
              ),
              child: Icon(
                Icons.storefront_rounded,
                size: 80,
                color: _isScanningNfc ? AppColors.turquesaVivo : AppColors.azulProfundo,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Descubre Ofertas",
              style: TextStyle(color: AppColors.azulMedianoche, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Escanea el código NFC o QR de una tienda\npara ver sus promociones exclusivas.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 48),

            // Botón NFC
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isScanningNfc ? AppColors.turquesaVivo : AppColors.azulProfundo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: (_isLoading || _isScanningNfc) ? null : _startNfcScan,
                icon: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(nfcIcon, color: Colors.white),
                label: Text(nfcText, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),

            // Botón QR
            if (!_isLoading && !_isScanningNfc)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.azulProfundo, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _startQrScan,
                  icon: Icon(Icons.qr_code_scanner, color: AppColors.azulProfundo),
                  label: const Text("ESCANEAR CÓDIGO QR", style: TextStyle(color: AppColors.azulProfundo, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              
             if (_isScanningNfc)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextButton(
                  onPressed: () async {
                    await NfcManager.instance.stopSession();
                    setState(() => _isScanningNfc = false);
                  },
                  child: const Text("Cancelar escaneo", style: TextStyle(color: Colors.grey)),
                ),
              )
          ],
        ),
      ),
    );
  }

  // --- VISTA 2: LISTA DE OFERTAS FILTRADA ---

  Widget _buildOffersList(String shopId) {
    return StreamBuilder<QuerySnapshot>(
      // Filtramos directamente aquí por 'shopId' y 'activa'
      stream: FirebaseFirestore.instance
          .collection('ofertas')
          .where('shopID', isEqualTo: shopId)
          .where('activa', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error al cargar ofertas"));
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            return _offerTile(
              context,
              data['titulo'] ?? "Oferta Especial",
              data['descripcion'] ?? "Disponible ahora",
              "CANJEAR",
              Icons.local_offer_rounded,
              data['codigo'] ?? "OFFER-000",
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.remove_shopping_cart_outlined, size: 80, color: AppColors.azulProfundo.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            "No hay ofertas para esta tienda",
            style: TextStyle(color: AppColors.azulMedianoche.withOpacity(0.6), fontSize: 18),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _resetView,
            child: const Text("Escanear otra tienda"),
          )
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES (Diálogo QR y Tile) ---

  void _mostrarQRCanje(BuildContext context, String titulo, String codigo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Canjear: $titulo", textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Muestra este código en caja:", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: codigo,
                  version: QrVersions.auto,
                  size: 200.0,
                  gapless: false,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.grisHielo,
                borderRadius: BorderRadius.circular(8)
              ),
              child: Text(
                codigo, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.5, color: AppColors.azulProfundo)
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _offerTile(BuildContext context, String title, String subtitle, String badge, IconData icon, String codigo) {
    return InkWell(
      onTap: () => _mostrarQRCanje(context, title, codigo),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.blancoPuro,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.aquaSuave,
                borderRadius: BorderRadius.circular(12)
              ),
              child: Icon(icon, color: AppColors.azulProfundo, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.azulMedianoche)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.turquesaVivo,
                borderRadius: BorderRadius.circular(20)
              ),
              child: Text(badge, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}