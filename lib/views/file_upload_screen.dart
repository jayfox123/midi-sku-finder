import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/column_mapping.dart';
import '../providers/sku_provider.dart';
import '../services/file_parser_service.dart';

class FileUploadScreen extends StatefulWidget {
  const FileUploadScreen({super.key});

  @override
  State<FileUploadScreen> createState() => _FileUploadScreenState();
}

class _FileUploadScreenState extends State<FileUploadScreen> {
  String? _selectedFilePath;
  FileParseResult? _parseResult;
  ColumnMapping _mapping = ColumnMapping();

  bool _isInspecting = false;
  String? _errorMessage;

  Future<void> _pickFile() async {
    setState(() {
      _isInspecting = true;
      _errorMessage = null;
    });

    try {
      final result = await FileParserService.pickAndInspectFile();
      if (result != null) {
        setState(() {
          _selectedFilePath = result.filePath;
          _parseResult = result;
          _mapping = ColumnMapping.autoDetect(result.headers, sampleRows: result.sampleRows);
          _isInspecting = false;
        });
      } else {
        setState(() {
          _isInspecting = false;
        });
      }
    } catch (e) {
      setState(() {
        _isInspecting = false;
        _errorMessage = 'Failed to inspect file: ${e.toString()}';
      });
    }
  }

  void _startImport() async {
    if (_selectedFilePath == null || _parseResult == null) return;

    if (!_mapping.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Barcode / SKU column!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final provider = Provider.of<SkuProvider>(context, listen: false);
    final barcodeHeader = (_mapping.barcodeColIndex >= 0 && _mapping.barcodeColIndex < _parseResult!.headers.length)
        ? _parseResult!.headers[_mapping.barcodeColIndex]
        : 'Barcode/SKU';

    final success = await provider.importFile(
      filePath: _selectedFilePath!,
      mapping: _mapping,
      fileName: _parseResult!.fileName,
      barcodeHeader: barcodeHeader,
    );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully loaded ${provider.totalCount} items in ${provider.activeModeLabel}!'),
          backgroundColor: Colors.green.shade800,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SkuProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Excel / CSV File'),
      ),
      body: SafeArea(
        bottom: true,
        child: provider.isImporting
            ? _buildImportProgressView(provider)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Active Loaded File Summary Card
                    if (provider.hasDataset) _buildActiveFileCard(context, provider),

                    const SizedBox(height: 12),

                    // File Picker Section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Step 1: Select Spreadsheet File',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Supports universal .xlsx, .xls and .csv formats (up to 100,000+ SKUs)',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: _isInspecting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.file_open),
                              label: Text(
                                _selectedFilePath != null ? 'Change File' : 'Browse Files (.xlsx / .csv)',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              onPressed: _isInspecting ? null : _pickFile,
                            ),
                            if (_selectedFilePath != null && _parseResult != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.insert_drive_file, color: Colors.green.shade800),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _parseResult!.fileName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Detected ~${_parseResult!.totalRowsEstimate} rows • ${_parseResult!.headers.length} columns',
                                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    if (_parseResult != null) ...[
                      const SizedBox(height: 16),

                      // Column Mapping & Scan Mode Section
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Step 2: Map Columns & Scan Mode',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _mapping.isDiscountMode ? Colors.green.shade100 : Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _mapping.isDiscountMode ? 'Discount Mode' : 'General Inventory',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _mapping.isDiscountMode ? Colors.green.shade900 : Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Select which column contains product Barcodes/SKUs. Other columns will be imported dynamically.',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              const SizedBox(height: 16),

                              // Barcode Dropdown (REQUIRED)
                              _buildDropdownField(
                                label: 'Barcode / SKU Column',
                                icon: Icons.qr_code,
                                selectedIndex: _mapping.barcodeColIndex,
                                isRequired: true,
                                onChanged: (val) {
                                  setState(() {
                                    _mapping.barcodeColIndex = val ?? -1;
                                  });
                                },
                              ),

                              const SizedBox(height: 12),

                              // Mode Switch / Discount toggle
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Enable Promo / Discount Pricing Card',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text(
                                  'Turn off for general inventory audits (quantity, aisle, supplier details)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                value: _mapping.isDiscountMode,
                                activeThumbColor: Colors.teal,
                                onChanged: (val) {
                                  setState(() {
                                    _mapping.forceGeneralMode = !val;
                                  });
                                },
                              ),

                              const Divider(height: 24),

                              if (_mapping.isDiscountMode) ...[
                                // Optional Title / Description Column
                                _buildDropdownField(
                                  label: 'Description / Item Title',
                                  icon: Icons.title,
                                  selectedIndex: _mapping.titleColIndex,
                                  onChanged: (val) {
                                    setState(() {
                                      _mapping.titleColIndex = val ?? -1;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Optional Discount Price Column
                                _buildDropdownField(
                                  label: 'Promo / Sale Price',
                                  icon: Icons.sell,
                                  selectedIndex: _mapping.discountPriceColIndex,
                                  onChanged: (val) {
                                    setState(() {
                                      _mapping.discountPriceColIndex = val ?? -1;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Optional Original Price Column
                                _buildDropdownField(
                                  label: 'Original / MSRP Price',
                                  icon: Icons.price_change,
                                  selectedIndex: _mapping.originalPriceColIndex,
                                  onChanged: (val) {
                                    setState(() {
                                      _mapping.originalPriceColIndex = val ?? -1;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],

                              const SizedBox(height: 12),

                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.download_for_offline),
                                label: Text(
                                  'INDEX ${_parseResult!.totalRowsEstimate}+ ITEMS FOR SCANNING',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                onPressed: _startImport,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildActiveFileCard(BuildContext context, SkuProvider provider) {
    return Card(
      elevation: 2,
      color: Colors.teal.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.teal.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.storage, color: Colors.teal.shade800),
                    const SizedBox(width: 8),
                    Text(
                      'Currently Active Dataset',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade900,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear File'),
                  onPressed: () => _confirmClearFile(context, provider),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              provider.fileName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${provider.totalCount} items loaded • Barcode Column: ${provider.detectedBarcodeHeader}',
                  style: TextStyle(fontSize: 12, color: Colors.teal.shade800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearFile(BuildContext context, SkuProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Active Dataset?'),
        content: const Text('This will remove all cached SKUs and reset the scanner.'),
        actions: [
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CLEAR FILE', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.clearDataset();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required int selectedIndex,
    required ValueChanged<int?> onChanged,
    bool isRequired = false,
  }) {
    final headers = _parseResult?.headers ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isRequired ? Colors.black87 : Colors.grey.shade800,
              ),
            ),
            if (isRequired)
              const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: (selectedIndex >= 0 && selectedIndex < headers.length) ? selectedIndex : null,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: isRequired ? 'Select Barcode Column' : 'Auto / Optional',
          ),
          items: [
            if (!isRequired)
              const DropdownMenuItem<int>(
                value: -1,
                child: Text('-- None / Ignore --', style: TextStyle(color: Colors.grey)),
              ),
            for (int i = 0; i < headers.length; i++)
              DropdownMenuItem<int>(
                value: i,
                child: Text(
                  '${headers[i].isNotEmpty ? headers[i] : 'Column ${i + 1}'}  (Col ${i + 1})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildImportProgressView(SkuProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 4),
            const SizedBox(height: 24),
            Text(
              provider.importStatusMessage,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: provider.importProgress > 0 ? provider.importProgress : null,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        ),
      ),
    );
  }
}
