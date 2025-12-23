import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
// Paquetes
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

// Importaciones propias (Asegúrate que las rutas coinciden con tu proyecto)
import '../../../config/app_colors.dart';
import '../../../services/parking_service.dart';
import '../../common/qr_scanner_screen.dart';

class ParkingTicketView extends StatefulWidget {
  const ParkingTicketView({super.key});

  @override
  State<ParkingTicketView> createState() => _ParkingTicketViewState();
}

class _ParkingTicketViewState extends State<ParkingTicketView> {
  // Instancia del servicio
  final ParkingService _parkingService = ParkingService();
  
  String? _currentTicketId;
  bool _isLoading = false;
  bool _isScanningNfc = false;
  bool _buscandoTicketInicial = true;

  @override
  void initState() {
    super.initState();
    _inicializarVista();
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  // --- 1. LÓGICA DE INICIO ---
  Future<void> _inicializarVista() async {
    
    await Future.delayed(const Duration(milliseconds: 100)); // Pequeña pausa para suavidad UI

    if (mounted) {
      setState(() {
        _currentTicketId = null; 
        _buscandoTicketInicial = false;
      });
    }
  }

  // --- 2. LÓGICA DE ESCANEO ---
  
  // Método centralizado que llama al servicio
  Future<void> _procesarEntrada(String gateId) async {
    setState(() => _isLoading = true);
    
    User? usuarioActual = FirebaseAuth.instance.currentUser;
    String uid = usuarioActual?.uid ?? 'usuario_invitado';

    try {
      // Llamamos al servicio para crear el ticket
      String newTicketId = await _parkingService.checkIn(uid, gateId, '1234 KLM');

      if (mounted) {
        setState(() {
          _currentTicketId = newTicketId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError("Error al generar ticket: $e");
      }
    }
  }

  void _startQrScan() async {
    // Navegamos a la pantalla de escáner separada
    final codigo = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );

    if (codigo != null && codigo is String) {
      _procesarEntrada(codigo);
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

            if (textoLeido.length > 2) textoLeido = textoLeido.substring(2);

            await NfcManager.instance.stopSession();
            
            if (mounted) {
              setState(() => _isScanningNfc = false);
              _procesarEntrada(textoLeido);
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

  // --- 3. LÓGICA DE SALIDA ---
  void _salirDelParking() async {
    setState(() => _isLoading = true); 

    try {
      // 1. IMPORTANTE: Cerrar ticket en Firebase para que no vuelva a salir
      if (_currentTicketId != null) {
        await _parkingService.checkOut(_currentTicketId!);
      }
      
      // 2. Reseteamos la vista local
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
        // Forzamos la salida local aunque falle la red para no bloquear al usuario
        setState(() => _currentTicketId = null);
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
    if (_buscandoTicketInicial) {
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
    // Texto e iconos dinámicos según estado
    String nfcText = _isScanningNfc ? "ACERCA EL MÓVIL..." : "ENTRAR CON NFC";
    IconData nfcIcon = _isScanningNfc ? Icons.wifi_tethering : Icons.nfc;
    if (_isLoading) nfcText = "GENERANDO TICKET...";

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
              _isScanningNfc ? "Buscando barrera..." : "Bienvenido al Parking",
              style: const TextStyle(color: AppColors.azulMedianoche, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Acerca tu móvil al punto NFC o escanea\nel código QR para entrar.",
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

  // --- VISTA B: TICKET ACTIVO ---
  Widget _buildActiveTicketView() {
    // Usamos el servicio para obtener el stream
    return StreamBuilder<DocumentSnapshot>(
      stream: _parkingService.getTicketStream(_currentTicketId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error al cargar ticket"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        if (!snapshot.data!.exists) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if(mounted) setState(() => _currentTicketId = null);
           });
           return const Center(child: Text("Ticket finalizado"));
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        
        Timestamp entrada = data['entrada'] ?? Timestamp.now();
        DateTime fechaEntrada = entrada.toDate();
        Duration tiempo = DateTime.now().difference(fechaEntrada);
        String tiempoTexto = "${tiempo.inHours}h ${tiempo.inMinutes.remainder(60)}m";
        
        String estado = data['estado'] ?? 'pendiente';
        bool isValidado = estado == 'validado';

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
                        color: isValidado ? Colors.green : AppColors.azulProfundo, 
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          Icon(isValidado ? Icons.check_circle : Icons.local_parking, color: Colors.white, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            isValidado ? "TICKET VALIDADO" : "TICKET ACTIVO",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            isValidado ? "Puedes salir del parking" : "Pendiente de pago/validación",
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
                              data: _currentTicketId ?? "error", 
                              version: QrVersions.auto,
                              size: 200.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(isValidado ? "¡Buen viaje!" : "Muestra este QR al salir", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const Divider(height: 40),
                          _row("Matrícula", data['matricula'] ?? "---"),
                          const SizedBox(height: 10),
                          _row("Hora Entrada", DateFormat('HH:mm').format(fechaEntrada)),
                          const SizedBox(height: 10),
                          _row("Tiempo aprox.", tiempoTexto),
                          const Divider(height: 40),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Estado:", style: TextStyle(fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isValidado ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20)
                                ),
                                child: Text(estado.toUpperCase(), style: TextStyle(color: isValidado ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
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
              if (isValidado) 
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