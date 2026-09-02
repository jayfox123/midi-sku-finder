import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/column_mapping.dart';
import '../models/sku_item.dart';
import '../services/database_service.dart';
import '../services/file_parser_service.dart';

class SkuProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  String _fileName = '';
  int _totalCount = 0;
  int _markedCount = 0;
  DateTime? _lastLoadedAt;

  bool _isImporting = false;
  double _importProgress = 0.0;
  String _importStatusMessage = '';

  // Getters
  String get fileName => _fileName;
  int get totalCount => _totalCount;
  int get markedCount => _markedCount;
  DateTime? get lastLoadedAt => _lastLoadedAt;
  bool get hasDataset => _totalCount > 0;

  bool get isImporting => _isImporting;
  double get importProgress => _importProgress;
  String get importStatusMessage => _importStatusMessage;

  SkuProvider() {
    loadSavedState();
  }

  /// Restores metadata on app start.
  Future<void> loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    _fileName = prefs.getString('sku_active_filename') ?? '';
    final loadedStr = prefs.getString('sku_last_loaded_at');
    if (loadedStr != null) {
      _lastLoadedAt = DateTime.tryParse(loadedStr);
    }

    await refreshStats();
  }

  Future<void> refreshStats() async {
    final stats = await _dbService.getStats();
    _totalCount = stats['total'] ?? 0;
    _markedCount = stats['marked'] ?? 0;
    notifyListeners();
  }

  /// Import dataset from file.
  Future<bool> importFile({
    required String filePath,
    required ColumnMapping mapping,
    required String fileName,
  }) async {
    _isImporting = true;
    _importProgress = 0.0;
    _importStatusMessage = 'Parsing $fileName...';
    notifyListeners();

    try {
      // 1. Parse File
      final items = await FileParserService.parseDataset(
        filePath: filePath,
        mapping: mapping,
        onProgress: (processed) {
          _importStatusMessage = 'Parsed $processed rows...';
          notifyListeners();
        },
      );

      if (items.isEmpty) {
        _isImporting = false;
        _importStatusMessage = 'No valid SKU items found in file.';
        notifyListeners();
        return false;
      }

      _importStatusMessage = 'Storing ${items.length} items in local database...';
      _importProgress = 0.5;
      notifyListeners();

      // 2. Batch replace into SQLite
      await _dbService.replaceDataset(
        items,
        onProgress: (processed, total) {
          _importProgress = 0.5 + (processed / total) * 0.5;
          _importStatusMessage = 'Imported $processed / $total items...';
          notifyListeners();
        },
      );

      // 3. Save preferences
      final now = DateTime.now();
      _fileName = fileName;
      _lastLoadedAt = now;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sku_active_filename', fileName);
      await prefs.setString('sku_last_loaded_at', now.toIso8601String());

      await refreshStats();

      _isImporting = false;
      _importProgress = 1.0;
      _importStatusMessage = 'Imported $_totalCount items successfully!';
      notifyListeners();
      return true;
    } catch (e) {
      _isImporting = false;
      _importStatusMessage = 'Import failed: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Lookup barcode against SQLite database.
  Future<SkuItem?> lookup(String barcode) async {
    return await _dbService.lookupBarcode(barcode);
  }

  /// Toggle item marked found status.
  Future<SkuItem?> toggleMarkedFound(SkuItem item) async {
    if (item.id == null) return null;
    final updated = await _dbService.toggleMarkedFound(item.id!, item.isMarkedFound);
    await refreshStats();
    return updated;
  }

  /// Clear dataset.
  Future<void> clearDataset() async {
    await _dbService.clearAllItems();
    _fileName = '';
    _lastLoadedAt = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sku_active_filename');
    await prefs.remove('sku_last_loaded_at');

    await refreshStats();
  }
}
