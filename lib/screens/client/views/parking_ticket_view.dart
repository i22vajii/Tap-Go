import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import '../../../config/app_colors.dart';
import '../../../services/parking_service.dart';
import '../../common/qr_scanner_screen.dart';

class ParkingTicketView extends StatefulWidget {
  // 1. INYECCIÓN: Servicio opcional para tests
  final ParkingService? service;

  const ParkingTicketView({super.key, this.service});

  @override
  State<ParkingTicketView> createState() => _ParkingTicketViewState();
}

class _ParkingTicketViewState extends State<ParkingTicketView> {
  // 2. Variable 'late final'
  late final ParkingService _parkingService;
  
  String? _currentTicketId;
  bool _isLoading = false;
  bool _isScanningNfc = false;
  bool _isInitializing = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 3. INICIALIZACIÓN: Usar mock o real
    _parkingService = widget.service ?? ParkingService();

    _buscarTicketActivo();
    
    // Timer para refrescar la UI (el cálculo de tiempo es relativo a DateTime.now())
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _currentTicketId != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    try { NfcManager.instance.stopSession(); } catch(e) {}
    super.dispose();
  }

  // --- 1. INICIALIZACIÓN ---
  Future<void> _buscarTicketActivo() async {
    final ticketId = await _parkingService.findActiveTicketId();
    if (mounted) {
      setState(() {
        _currentTicketId = ticketId;
        _isInitializing = false;
      });
    }
  }

  // --- 2. PROCESAR ENTRADA (Delegado al Servicio) ---
  Future<void> _procesarCodigo(String rawData) async {
    setState(() => _isLoading = true);
    
    try {
      String newTicketId = await _parkingService.checkIn(rawData);

      if (mounted) {
        setState(() {
          _currentTicketId = newTicketId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(e.toString());
      }
    }
  }

  // --- 3. PROCESAR SALIDA ---
  void _salirDelParking() async {
    setState(() => _isLoading = true); 
    try {
      if (_currentTicketId != null) {
        await _parkingService.checkOut(_currentTicketId!);
      }
      if (mounted) {
        setState(() {
          _currentTicketId = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError("Error al salir: $e");
        setState(() => _currentTicketId = null);
      }
    }
  }

  // --- ESCANEO HARDWARE ---
  void _startQrScan() async {
    final codigo = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
    if (codigo != null && codigo is String) {
      _procesarCodigo(codigo);
    }
  }

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
            
            // Usamos el helper del servicio para limpiar el string NFC
            textoLeido = _parkingService.cleanNfcPayload(textoLeido);

            await NfcManager.instance.stopSession();
            
            if (mounted) {
              setState(() => _isScanningNfc = false);
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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // --- UI PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Mi Parking")),
      backgroundColor: AppColors.grisHielo,
      body: _currentTicketId == null 
          ? _buildScannerView()
          : _buildActiveTicketView(),
    );
  }

  // --- VISTA A: ESCÁNER ---
  Widget _buildScannerView() {
    String nfcText = _isScanningNfc ? "ACERCA EL MÓVIL..." : "ENTRAR CON NFC";
    if (_isLoading) nfcText = "VALIDANDO CÓDIGO...";

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
                Icons.local_parking_rounded,
                size: 80,
                color: _isScanningNfc ? AppColors.turquesaVivo : AppColors.azulProfundo,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _isScanningNfc ? "Buscando etiqueta..." : "Bienvenido al Parking",
              style: const TextStyle(color: AppColors.azulMedianoche, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Usa NFC o QR del parking para registrar tu entrada.",
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
                    : Icon(_isScanningNfc ? Icons.wifi_tethering : Icons.nfc, color: Colors.white),
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

  // --- VISTA B: TICKET ACTIVO (Tipada con Modelo) ---
  Widget _buildActiveTicketView() {
    return StreamBuilder<ParkingTicket>(
      stream: _parkingService.getTicketStream(_currentTicketId!),
      builder: (context, snapshot) {
        
        // Manejo de estados del Stream
        if (snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if(mounted && _currentTicketId != null) setState(() => _currentTicketId = null);
          });
          return const Center(child: Text("Ticket finalizado o no encontrado"));
        }
        
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final ticket = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(color: AppColors.blancoPuro, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ticket.isValidated ? Colors.green : AppColors.azulProfundo, 
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          Icon(ticket.isValidated ? Icons.check_circle : Icons.local_parking, color: Colors.white, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            ticket.isValidated ? "TICKET VALIDADO" : "TICKET ACTIVO",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            ticket.isValidated ? "Puedes salir del parking" : "Ubicación: ${ticket.shopId}",
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          )
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 180,
                            width: 180,
                            child: QrImageView(
                              data: ticket.id, 
                              version: QrVersions.auto,
                              size: 200.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(ticket.isValidated ? "¡Buen viaje!" : "Muestra este QR al salir", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const Divider(height: 40),
                          _row("Hora Entrada", DateFormat('HH:mm').format(ticket.entryTime)),
                          const SizedBox(height: 10),
                          _row("Tiempo aprox.", ticket.formattedDuration),
                          const Divider(height: 40),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Estado:", style: TextStyle(fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: ticket.isValidated ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20)
                                ),
                                child: Text(ticket.status.toUpperCase(), style: TextStyle(color: ticket.isValidated ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              if (ticket.isValidated) 
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _salirDelParking,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulProfundo),
                    child: const Text("SALIR DEL PARKING", style: TextStyle(color: Colors.white)),
                  ),
                )
              else
                TextButton(
                  onPressed: _salirDelParking,
                  child: const Text("Cancelar Demo (Reset)", style: TextStyle(color: Colors.grey)),
                )
            ],
          ),
        );
      },
    );
  }

  Widget _row(String k, String v) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
    children: [
      Text(k, style: const TextStyle(color: Colors.grey)), 
      Text(v, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.azulMedianoche))
    ]
  );
}