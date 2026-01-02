import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import '../../../config/app_colors.dart';
import '../../../services/offers_service.dart';
import '../../common/qr_scanner_screen.dart';

class OffersListView extends StatefulWidget {
  // Parámetros opcionales para TESTING
  final OffersService? service;
  final String? initialShopId;

  const OffersListView({
    super.key, 
    this.service, 
    this.initialShopId
  });

  @override
  State<OffersListView> createState() => _OffersListViewState();
}

class _OffersListViewState extends State<OffersListView> {
  // 1. Declaramos el servicio como 'late final' para inicializarlo después
  late final OffersService _offersService;

  // 2. Variables de estado
  String? _currentShopId;
  bool _isScanningNfc = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 3. INYECCIÓN: Si viene del test usamos ese, si no, creamos el real.
    _offersService = widget.service ?? OffersService();
    
    // 4. ESTADO INICIAL: Si el test nos da un ID, empezamos con él directamente.
    _currentShopId = widget.initialShopId;
  }

  @override
  void dispose() {
    // En un entorno de test o simulador, NfcManager podría lanzar error al parar
    try {
      NfcManager.instance.stopSession();
    } catch (e) {
      // Ignoramos errores de cierre de sesión NFC
    }
    super.dispose();
  }

  // --- LÓGICA DE PROCESAMIENTO (Delegada al Servicio) ---

  void _procesarCodigo(String rawCode) {
    // Usamos el servicio para extraer el ID limpio
    final shopId = _offersService.extractShopId(rawCode);

    setState(() {
      _currentShopId = shopId;
      _isLoading = false;
      _isScanningNfc = false;
    });
  }

  // --- LÓGICA DE ESCANEO (Hardware) ---

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

            // Usamos el servicio para limpiar el payload NFC
            textoLeido = _offersService.cleanNfcPayload(textoLeido);

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
    // Asumimos que QrScannerScreen devuelve un String nullable
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

  // --- VISTA 1: ESCÁNER ---
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

  // --- VISTA 2: LISTA DE OFERTAS ---

  Widget _buildOffersList(String shopId) {
    return StreamBuilder<List<OfferModel>>(
      // Usamos el servicio inyectado
      stream: _offersService.getOffersByShop(shopId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error al cargar ofertas"));
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        final offers = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: offers.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final offer = offers[index];
            
            return _offerTile(
              context,
              offer.title,
              offer.description,
              "CANJEAR",
              Icons.local_offer_rounded,
              offer.code,
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

  // --- WIDGETS AUXILIARES ---

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