import 'package:file_picker/file_picker.dart';
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
      _errorMessage = null;
      _isInspecting = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        final path = result.files.single.path!;
        final inspected = await FileParserService.inspectFile(path);
        final autoMapping = ColumnMapping.autoDetect(inspected.headers);

        setState(() {
          _selectedFilePath = path;
          _parseResult = inspected;
          _mapping = autoMapping;
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

    final success = await provider.importFile(
      filePath: _selectedFilePath!,
      mapping: _mapping,
      fileName: _parseResult!.fileName,
    );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully loaded ${provider.totalCount} items!'),
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
                            'Supports .xlsx, .xls and .csv formats (up to 100,000+ SKUs)',
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
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade900,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Found ${_parseResult!.headers.length} columns (~${_parseResult!.estimatedRowCount} estimated rows)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green.shade800,
                                          ),
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
                    const SizedBox(height: 20),

                    // Column Mapping Section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Step 2: Map File Columns',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.auto_awesome, size: 18),
                                  label: const Text('Auto Detect'),
                                  onPressed: () {
                                    setState(() {
                                      _mapping = ColumnMapping.autoDetect(_parseResult!.headers);
                                    });
                                  },
                                ),
                              ],
                            ),
                            const Text(
                              'Assign columns from your file to the application fields:',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 16),

                            _buildDropdownField(
                              label: 'Barcode / SKU Column *',
                              icon: Icons.qr_code,
                              isRequired: true,
                              selectedIndex: _mapping.barcodeColIndex,
                              onChanged: (val) {
                                setState(() {
                                  _mapping.barcodeColIndex = val ?? -1;
                                });
                              },
                            ),
                            _buildDropdownField(
                              label: 'Product Title / Description',
                              icon: Icons.title,
                              selectedIndex: _mapping.titleColIndex,
                              onChanged: (val) {
                                setState(() {
                                  _mapping.titleColIndex = val ?? -1;
                                });
                              },
                            ),
                            _buildDropdownField(
                              label: 'Department / Category',
                              icon: Icons.category,
                              selectedIndex: _mapping.categoryColIndex,
                              onChanged: (val) {
                                setState(() {
                                  _mapping.categoryColIndex = val ?? -1;
                                });
                              },
                            ),
                            _buildDropdownField(
                              label: 'Original Price (Old Price)',
                              icon: Icons.money_off,
                              selectedIndex: _mapping.originalPriceColIndex,
                              onChanged: (val) {
                                setState(() {
                                  _mapping.originalPriceColIndex = val ?? -1;
                                });
                              },
                            ),
                            _buildDropdownField(
                              label: 'Discount / Promo Sale Price',
                              icon: Icons.sell,
                              selectedIndex: _mapping.discountPriceColIndex,
                              onChanged: (val) {
                                setState(() {
                                  _mapping.discountPriceColIndex = val ?? -1;
                                });
                              },
                            ),
                            _buildDropdownField(
                              label: 'Location / Aisle / Notes',
                              icon: Icons.place,
                              selectedIndex: _mapping.locationNotesColIndex,
                              onChanged: (val) {
                                setState(() {
                                  _mapping.locationNotesColIndex = val ?? -1;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Import Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.bolt, size: 24),
                      label: const Text(
                        'IMPORT & LOAD DATASET',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _startImport,
                    ),
                  ],
                ],
              ),
            ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: isRequired ? Colors.red.shade700 : Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isRequired ? FontWeight.bold : FontWeight.w500,
                  color: isRequired ? Colors.red.shade800 : null,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: selectedIndex >= 0 && selectedIndex < headers.length ? selectedIndex : null,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            hint: const Text('-- Select Column --'),
            items: [
              const DropdownMenuItem<int>(
                value: -1,
                child: Text('-- None / Skip --', style: TextStyle(color: Colors.grey)),
              ),
              for (int i = 0; i < headers.length; i++)
                DropdownMenuItem<int>(
                  value: i,
                  child: Text(
                    'Col ${i + 1}: ${headers[i]}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildImportProgressView(SkuProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: provider.importProgress > 0 ? provider.importProgress : null,
              strokeWidth: 6,
              color: Colors.green.shade700,
            ),
            const SizedBox(height: 24),
            Text(
              provider.importStatusMessage,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: provider.importProgress > 0 ? provider.importProgress : null,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: Colors.green.shade700,
            ),
            const SizedBox(height: 16),
            const Text(
              'Optimizing SQLite database index for zero-latency lookups...',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
