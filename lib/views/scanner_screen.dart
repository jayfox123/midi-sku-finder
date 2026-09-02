import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/sku_provider.dart';
import '../services/audio_feedback_service.dart';
import 'scan_result_dialog.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late MobileScannerController _controller;

  bool _isProcessing = false;
  bool _torchOn = false;
  PermissionStatus _cameraPermissionStatus = PermissionStatus.denied;
  bool _isCheckingPermission = true;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (mounted) {
        setState(() {
          _cameraPermissionStatus = status;
          _isCheckingPermission = false;
        });
      }
    } else {
      final requested = await Permission.camera.request();
      if (mounted) {
        setState(() {
          _cameraPermissionStatus = requested;
          _isCheckingPermission = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawBarcode = barcodes.first.rawValue ?? barcodes.first.displayValue;
    if (rawBarcode == null || rawBarcode.trim().isEmpty) return;

    _processBarcode(rawBarcode.trim());
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
            child: const Text('CANCEL'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text('LOOKUP'),
            onPressed: () {
              final val = textController.text.trim();
              Navigator.pop(ctx);
              if (val.isNotEmpty) {
                _processBarcode(val);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isCheckingPermission
          ? const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            )
          : !_cameraPermissionStatus.isGranted
              ? _buildPermissionDeniedView()
              : Stack(
                  children: [
                    // Live Camera Feed with detailed error builder
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error, child) {
                        return _buildCameraErrorView(error);
                      },
                    ),

                    // Viewfinder reticle overlay
                    _buildReticleOverlay(),

                    // Top Control Bar
                    SafeArea(
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
                                    onPressed: () {
                                      _controller.toggleTorch();
                                      setState(() {
                                        _torchOn = !_torchOn;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  backgroundColor: Colors.black54,
                                  child: IconButton(
                                    icon: const Icon(Icons.cameraswitch, color: Colors.white),
                                    onPressed: () => _controller.switchCamera(),
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

                    // Bottom Instruction Bar
                    Positioned(
                      bottom: 40,
                      left: 20,
                      right: 20,
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
                  ],
                ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
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
                } else {
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
    );
  }

  Widget _buildCameraErrorView(MobileScannerException error) {
    String errorMsg = error.errorDetails?.message ?? error.errorCode.name;
    if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
      errorMsg = 'Camera permission denied.';
    }

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Camera Error',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Code: ${error.errorCode.name}\nDetails: $errorMsg',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY CAMERA'),
              onPressed: () {
                _controller.start();
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.keyboard),
              label: const Text('USE MANUAL BARCODE ENTRY'),
              onPressed: _showManualBarcodeDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReticleOverlay() {
    return Center(
      child: Container(
        width: 280,
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(
            color: _isProcessing ? Colors.orange : Colors.green.shade400,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (_isProcessing ? Colors.orange : Colors.green).withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Center scanning line animation effect
            Center(
              child: Container(
                height: 2,
                color: Colors.redAccent.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
