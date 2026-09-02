import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import '../providers/sku_provider.dart';
import '../services/audio_feedback_service.dart';
import 'scan_result_dialog.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  bool _isProcessing = false;
  bool _torchOn = false;
  bool _hasPermission = false;
  bool _isCheckingPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCameraPermission();
  }

  // Hot reload fix for Android camera view
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (mounted) {
        setState(() {
          _hasPermission = true;
          _isCheckingPermission = false;
        });
      }
    } else {
      final requested = await Permission.camera.request();
      if (mounted) {
        setState(() {
          _hasPermission = requested.isGranted;
          _isCheckingPermission = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || !_hasPermission) return;
    if (state == AppLifecycleState.resumed) {
      controller?.resumeCamera();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      controller?.pauseCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (_isProcessing) return;
      final rawBarcode = scanData.code;
      if (rawBarcode != null && rawBarcode.trim().isNotEmpty) {
        _processBarcode(rawBarcode.trim());
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    if (!p && mounted) {
      setState(() {
        _hasPermission = false;
      });
    }
  }

  Future<void> _processBarcode(String barcode) async {
    setState(() {
      _isProcessing = true;
    });

    await AudioFeedbackService.playScanSuccess();

    if (!mounted) return;
    final provider = Provider.of<SkuProvider>(context, listen: false);
    final match = await provider.lookup(barcode);

    if (mounted) {
      await ScanResultDialog.show(
        context,
        barcode: barcode,
        item: match,
        onScanNext: () {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
        },
      );
    }
  }

  void _showManualBarcodeDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual Barcode Entry'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter barcode or SKU number',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.numbers),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = textController.text.trim();
              Navigator.pop(ctx);
              if (val.isNotEmpty) {
                _processBarcode(val);
              }
            },
            child: const Text('LOOKUP'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isCheckingPermission) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.teal),
      );
    }

    if (!_hasPermission) {
      return _buildPermissionDeniedView();
    }

    return Stack(
      children: [
        // QR / Barcode Camera Feed
        QRView(
          key: qrKey,
          onQRViewCreated: _onQRViewCreated,
          overlay: QrScannerOverlayShape(
            borderColor: _isProcessing ? Colors.orange : Colors.green.shade400,
            borderRadius: 16,
            borderLength: 30,
            borderWidth: 8,
            cutOutSize: 280,
          ),
          onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
        ),

        // Top Control Bar (SafeArea protected)
        SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: Icon(
                          _torchOn ? Icons.flash_on : Icons.flash_off,
                          color: _torchOn ? Colors.amber : Colors.white,
                        ),
                        onPressed: () async {
                          await controller?.toggleFlash();
                          final status = await controller?.getFlashStatus();
                          if (mounted) {
                            setState(() {
                              _torchOn = status ?? !_torchOn;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.cameraswitch, color: Colors.white),
                        onPressed: () async {
                          await controller?.flipCamera();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.edit_note, color: Colors.white),
                        tooltip: 'Manual Entry',
                        onPressed: _showManualBarcodeDialog,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Bottom Instruction Bar (SafeArea bottom protected from Android nav bar)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.center_focus_weak, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Point camera at item barcode',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionDeniedView() {
    return SafeArea(
      bottom: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              const Text(
                'Camera Permission Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'MIDI SKU Finder requires access to your camera to scan item barcodes.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                icon: const Icon(Icons.settings),
                label: const Text('GRANT CAMERA PERMISSION'),
                onPressed: () async {
                  final status = await Permission.camera.request();
                  if (status.isPermanentlyDenied) {
                    await openAppSettings();
                  } else if (status.isGranted) {
                    _checkCameraPermission();
                  }
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _showManualBarcodeDialog,
                child: const Text('Enter Barcode Manually', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
