import 'package:path/path.dart' as p_path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/sku_item.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p_path.join(docsDir.path, 'midi_skus.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            barcode TEXT NOT NULL,
            raw_barcode TEXT,
            title TEXT,
            category TEXT,
            original_price REAL,
            discount_price REAL,
            location_notes TEXT,
            is_marked_found INTEGER DEFAULT 0,
            marked_at TEXT,
            raw_data_json TEXT
          )
        ''');

        // Create high-performance index on barcode column
        await db.execute('CREATE INDEX idx_items_barcode ON items(barcode)');
        await db.execute('CREATE INDEX idx_items_marked ON items(is_marked_found)');
      },
    );
  }

  /// Bulk insert up to 100,000+ items using batched transactions.
  Future<void> replaceDataset(
    List<SkuItem> items, {
    void Function(int processed, int total)? onProgress,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.execute('DELETE FROM items');

      const chunkSize = 2000;
      final total = items.length;

      for (int i = 0; i < total; i += chunkSize) {
        final end = (i + chunkSize < total) ? i + chunkSize : total;
        final batch = txn.batch();
        for (int j = i; j < end; j++) {
          batch.insert(
            'items',
            items[j].toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        if (onProgress != null) {
          onProgress(end, total);
        }
      }
    });
  }

  /// Zero-latency O(1) indexed lookup for scanned barcodes.
  Future<SkuItem?> lookupBarcode(String rawBarcode) async {
    final db = await database;
    String normalized = SkuItem.normalizeBarcode(rawBarcode);

    if (normalized.isEmpty) return null;

    // 1. Direct indexed match
    List<Map<String, dynamic>> results = await db.query(
      'items',
      where: 'barcode = ?',
      whereArgs: [normalized],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return SkuItem.fromMap(results.first);
    }

    // 2. Strip leading zero fallback (e.g. UPC-A / EAN-13 variants)
    if (normalized.startsWith('0') && normalized.length > 1) {
      String stripped = normalized.substring(1);
      results = await db.query(
        'items',
        where: 'barcode = ?',
        whereArgs: [stripped],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return SkuItem.fromMap(results.first);
      }
    } else {
      // Add leading zero fallback
      String padded = '0$normalized';
      results = await db.query(
        'items',
        where: 'barcode = ?',
        whereArgs: [padded],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return SkuItem.fromMap(results.first);
      }
    }

    return null;
  }

  /// Toggle item "Mark Found / Isolated" state.
  Future<SkuItem?> toggleMarkedFound(int id, bool currentStatus) async {
    final db = await database;
    final newStatus = !currentStatus;
    final nowStr = newStatus ? DateTime.now().toIso8601String() : null;

    await db.update(
      'items',
      {
        'is_marked_found': newStatus ? 1 : 0,
        'marked_at': nowStr,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    final res = await db.query('items', where: 'id = ?', whereArgs: [id], limit: 1);
    if (res.isNotEmpty) {
      return SkuItem.fromMap(res.first);
    }
    return null;
  }

  /// Clear all stored dataset items.
  Future<void> clearAllItems() async {
    final db = await database;
    await db.delete('items');
  }

  /// Get dataset statistics.
  Future<Map<String, int>> getStats() async {
    final db = await database;
    final totalRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM items');
    final totalCount = Sqflite.firstIntValue(totalRes) ?? 0;

    final markedRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM items WHERE is_marked_found = 1');
    final markedCount = Sqflite.firstIntValue(markedRes) ?? 0;

    return {
      'total': totalCount,
      'marked': markedCount,
    };
  }

  /// Search SKUs in database.
  Future<List<SkuItem>> searchItems({
    String query = '',
    bool? onlyMarked,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      whereClauses.add('(barcode LIKE ? OR title LIKE ? OR category LIKE ? OR location_notes LIKE ?)');
      whereArgs.addAll([q, q, q, q]);
    }

    if (onlyMarked == true) {
      whereClauses.add('is_marked_found = 1');
    }

    String? where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final maps = await db.query(
      'items',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'is_marked_found DESC, id ASC',
      limit: limit,
      offset: offset,
    );

    return maps.map((m) => SkuItem.fromMap(m)).toList();
  }
}
