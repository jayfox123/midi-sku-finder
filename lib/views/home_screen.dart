import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sku_provider.dart';
import 'file_upload_screen.dart';
import 'item_list_screen.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skuProvider = Provider.of<SkuProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/app_icon.png', width: 28, height: 28),
            ),
            const SizedBox(width: 10),
            const Text(
              'MIDI SKU Finder',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'App Info',
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'MIDI SKU Finder',
                applicationVersion: '1.0.0',
                applicationIcon: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('assets/app_icon.png', width: 48, height: 48),
                ),
                children: [
                  const Text('Offline Android Barcode Scanner & Retail SKU Finder.'),
                  const SizedBox(height: 8),
                  const Text('Designed to process up to 100,000+ SKUs with instant zero-latency lookups.'),
                  const SizedBox(height: 12),
                  Text(
                    'Developed by: Jay Orog',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            _buildStatusCard(context, skuProvider),

            const SizedBox(height: 20),

            // Action Buttons
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.camera_alt, size: 28),
              label: const Text(
                'START BARCODE SCANNER',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              onPressed: () {
                if (!skuProvider.hasDataset) {
                  _showNoDatasetSnackbar(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScannerScreen()),
                );
              },
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.blue.shade600, width: 1.5),
                    ),
                    icon: Icon(Icons.upload_file, color: Colors.blue.shade700),
                    label: Text(
                      skuProvider.hasDataset ? 'Replace File' : 'Upload File',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FileUploadScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.purple.shade600, width: 1.5),
                    ),
                    icon: Icon(Icons.list_alt, color: Colors.purple.shade700),
                    label: Text(
                      'Browse SKUs',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                    onPressed: () {
                      if (!skuProvider.hasDataset) {
                        _showNoDatasetSnackbar(context);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ItemListScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Quick Usage Guide Card
            _buildInstructionsCard(context),

            const SizedBox(height: 24),

            // Developer Credit
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Developed by: Jay Orog',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, SkuProvider provider) {
    final hasData = provider.hasDataset;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: hasData
                ? [Colors.teal.shade800, Colors.teal.shade900]
                : [Colors.grey.shade800, Colors.grey.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasData ? Colors.green.shade400 : Colors.orange.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasData ? 'DATABASE ACTIVE' : 'NO FILE LOADED',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hasData)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white70),
                    tooltip: 'Clear Dataset',
                    onPressed: () => _confirmClear(context, provider),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hasData ? provider.fileName : 'No Discount File Loaded',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildStatItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Total SKUs',
                  value: provider.totalCount > 0 ? '${provider.totalCount}' : '0',
                ),
                const SizedBox(width: 24),
                _buildStatItem(
                  icon: Icons.check_circle_outline,
                  label: 'Marked Found',
                  value: '${provider.markedCount}',
                  highlightColor: Colors.lightGreenAccent,
                ),
              ],
            ),
            if (hasData && provider.lastLoadedAt != null) ...[
              const Divider(color: Colors.white24, height: 24),
              Text(
                'Loaded: ${_formatDateTime(provider.lastLoadedAt!)}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    Color? highlightColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: highlightColor ?? Colors.white70, size: 22),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: highlightColor ?? Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstructionsCard(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).cardColor,
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Quick Setup Guide',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            _InstructionStep(
              number: '1',
              title: 'Upload Store Discount List',
              description: 'Select your Excel (.xlsx) or CSV file with product barcodes & promotional prices.',
            ),
            SizedBox(height: 8),
            _InstructionStep(
              number: '2',
              title: 'Map Columns',
              description: 'Ensure the Barcode/SKU column is correctly selected.',
            ),
            SizedBox(height: 8),
            _InstructionStep(
              number: '3',
              title: 'Start Scanning',
              description: 'Scan items on the shelf. Green banner means MATCH, red means NOT ON LIST.',
            ),
            SizedBox(height: 8),
            _InstructionStep(
              number: '4',
              title: 'Isolate & Mark Found',
              description: 'Tap "Mark Found" to record items physically pulled from floor.',
            ),
          ],
        ),
      ),
    );
  }

  void _showNoDatasetSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please upload an Excel or CSV file first!'),
        backgroundColor: Colors.orange.shade800,
        action: SnackBarAction(
          label: 'UPLOAD NOW',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FileUploadScreen()),
            );
          },
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, SkuProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Dataset?'),
        content: const Text('This will delete all currently cached SKUs and marked items from local storage.'),
        actions: [
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CLEAR DATA', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.clearDataset();
            },
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InstructionStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _InstructionStep({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: Colors.green.shade700,
          child: Text(
            number,
            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                description,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
