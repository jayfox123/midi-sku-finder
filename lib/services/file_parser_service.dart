import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../models/column_mapping.dart';
import '../models/sku_item.dart';

class FileParseResult {
  final String filePath;
  final List<String> headers;
  final List<List<dynamic>> sampleRows;
  final String fileName;
  final int estimatedRowCount;

  FileParseResult({
    required this.filePath,
    required this.headers,
    required this.sampleRows,
    required this.fileName,
    required this.estimatedRowCount,
  });

  int get totalRowsEstimate => estimatedRowCount;
}

class FileParserService {
  /// Open file picker and inspect headers + preview rows.
  static Future<FileParseResult?> pickAndInspectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result == null || result.files.single.path == null) return null;
    return await inspectFile(result.files.single.path!);
  }

  /// Reads headers and sample preview rows from CSV or Excel file.
  static Future<FileParseResult> inspectFile(String filePath) async {
    final file = File(filePath);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final isCsv = fileName.toLowerCase().endsWith('.csv');

    if (isCsv) {
      return _inspectCsv(file, fileName, filePath);
    } else {
      return _inspectExcel(file, fileName, filePath);
    }
  }

  static Future<FileParseResult> _inspectCsv(File file, String fileName, String filePath) async {
    final input = file.openRead();
    final fields = await input
        .transform(utf8.decoder)
        .transform(const CsvToListConverter(shouldParseNumbers: false))
        .take(10)
        .toList();

    if (fields.isEmpty) {
      throw Exception('CSV file is empty');
    }

    final headers = fields.first.map((e) => e.toString().trim()).toList();
    final sampleRows = fields.skip(1).toList();

    // Estimate row count from file size
    final length = await file.length();
    int estRows = (length / 80).round();
    if (estRows < fields.length) estRows = fields.length;

    return FileParseResult(
      filePath: filePath,
      headers: headers,
      sampleRows: sampleRows,
      fileName: fileName,
      estimatedRowCount: estRows,
    );
  }

  static Future<FileParseResult> _inspectExcel(File file, String fileName, String filePath) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      throw Exception('Excel workbook contains no sheets');
    }

    final sheetName = excel.tables.keys.first;
    final table = excel.tables[sheetName]!;

    if (table.rows.isEmpty) {
      throw Exception('Excel sheet is empty');
    }

    final headers = table.rows.first.map((cell) => cell?.value?.toString().trim() ?? '').toList();
    final sampleRows = table.rows
        .skip(1)
        .take(10)
        .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
        .toList();

    return FileParseResult(
      filePath: filePath,
      headers: headers,
      sampleRows: sampleRows,
      fileName: fileName,
      estimatedRowCount: table.rows.length - 1,
    );
  }

  /// Parses entire CSV or Excel file using given ColumnMapping into SkuItems list.
  static Future<List<SkuItem>> parseDataset({
    required String filePath,
    required ColumnMapping mapping,
    void Function(int processed)? onProgress,
  }) async {
    final file = File(filePath);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final isCsv = fileName.toLowerCase().endsWith('.csv');

    if (isCsv) {
      return _parseCsv(file, mapping, onProgress);
    } else {
      return _parseExcel(file, mapping, onProgress);
    }
  }

  static Future<List<SkuItem>> _parseCsv(
    File file,
    ColumnMapping mapping,
    void Function(int processed)? onProgress,
  ) async {
    final input = file.openRead();
    final rows = await input
        .transform(utf8.decoder)
        .transform(const CsvToListConverter(shouldParseNumbers: false))
        .toList();

    if (rows.isEmpty) return [];

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    List<SkuItem> items = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final item = _buildSkuItemFromRow(headers, row, mapping);
      if (item != null) {
        items.add(item);
      }

      if (onProgress != null && i % 2000 == 0) {
        onProgress(i);
      }
    }

    return items;
  }

  static Future<List<SkuItem>> _parseExcel(
    File file,
    ColumnMapping mapping,
    void Function(int processed)? onProgress,
  ) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) return [];

    final sheetName = excel.tables.keys.first;
    final table = excel.tables[sheetName]!;

    if (table.rows.length <= 1) return [];

    final headers = table.rows.first.map((cell) => cell?.value?.toString().trim() ?? '').toList();
    List<SkuItem> items = [];

    for (int r = 1; r < table.rows.length; r++) {
      final rowCells = table.rows[r];
      final rowValues = rowCells.map((cell) => cell?.value?.toString() ?? '').toList();

      final item = _buildSkuItemFromRow(headers, rowValues, mapping);
      if (item != null) {
        items.add(item);
      }

      if (onProgress != null && r % 2000 == 0) {
        onProgress(r);
      }
    }

    return items;
  }

  static SkuItem? _buildSkuItemFromRow(
    List<String> headers,
    List<dynamic> row,
    ColumnMapping mapping,
  ) {
    if (mapping.barcodeColIndex < 0 || mapping.barcodeColIndex >= row.length) {
      return null;
    }

    String rawBarcode = row[mapping.barcodeColIndex]?.toString().trim() ?? '';
    if (rawBarcode.isEmpty) return null;

    Map<String, dynamic> rawData = {};
    for (int c = 0; c < row.length && c < headers.length; c++) {
      String headerName = headers[c].trim().isNotEmpty ? headers[c].trim() : 'Col ${c + 1}';
      rawData[headerName] = row[c]?.toString().trim() ?? '';
    }

    String title = _getStringValue(row, mapping.titleColIndex);
    if (title.isEmpty) {
      // Find first non-empty text column that isn't the barcode column
      for (int c = 0; c < row.length; c++) {
        if (c != mapping.barcodeColIndex) {
          String val = row[c]?.toString().trim() ?? '';
          if (val.isNotEmpty && !RegExp(r'^\d{8,14}$').hasMatch(val)) {
            title = val;
            break;
          }
        }
      }
      if (title.isEmpty) title = 'Item $rawBarcode';
    }

    String category = _getStringValue(row, mapping.categoryColIndex);
    double? origPrice = _parsePrice(row, mapping.originalPriceColIndex);
    double? discPrice = _parsePrice(row, mapping.discountPriceColIndex);
    String location = _getStringValue(row, mapping.locationNotesColIndex);

    return SkuItem(
      barcode: rawBarcode,
      title: title,
      category: category,
      originalPrice: origPrice,
      discountPrice: discPrice,
      locationNotes: location,
      rawData: rawData,
    );
  }

  static String _getStringValue(List<dynamic> row, int index, {String fallback = ''}) {
    if (index >= 0 && index < row.length) {
      final val = row[index]?.toString().trim() ?? '';
      if (val.isNotEmpty) return val;
    }
    return fallback;
  }

  static double? _parsePrice(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return null;
    final valStr = row[index]?.toString().trim() ?? '';
    if (valStr.isEmpty) return null;

    // Clean price string e.g. "$14.99", "14,99 €", "USD 14.99"
    final cleaned = valStr.replaceAll(RegExp(r'[^\d\.\,]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }
}
