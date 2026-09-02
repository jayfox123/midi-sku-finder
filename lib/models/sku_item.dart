import 'dart:convert';

class SkuItem {
  final int? id;
  final String barcode;
  final String title;
  final String category;
  final double? originalPrice;
  final double? discountPrice;
  final String locationNotes;
  final bool isMarkedFound;
  final DateTime? markedAt;
  final Map<String, dynamic> rawData;

  SkuItem({
    this.id,
    required this.barcode,
    required this.title,
    this.category = '',
    this.originalPrice,
    this.discountPrice,
    this.locationNotes = '',
    this.isMarkedFound = false,
    this.markedAt,
    this.rawData = const {},
  });

  /// Normalizes a barcode string for resilient matching (trims whitespace, uppercase, strips leading zero if needed).
  static String normalizeBarcode(String raw) {
    String cleaned = raw.trim().replaceAll(RegExp(r'[\s\-\_]'), '');
    return cleaned;
  }

  /// Calculates percentage discount savings.
  double? get discountPercentage {
    if (originalPrice != null &&
        discountPrice != null &&
        originalPrice! > 0 &&
        discountPrice! < originalPrice!) {
      return ((originalPrice! - discountPrice!) / originalPrice!) * 100;
    }
    return null;
  }

  /// Amount saved.
  double? get savingsAmount {
    if (originalPrice != null && discountPrice != null) {
      return originalPrice! - discountPrice!;
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': normalizeBarcode(barcode),
      'raw_barcode': barcode,
      'title': title,
      'category': category,
      'original_price': originalPrice,
      'discount_price': discountPrice,
      'location_notes': locationNotes,
      'is_marked_found': isMarkedFound ? 1 : 0,
      'marked_at': markedAt?.toIso8601String(),
      'raw_data_json': jsonEncode(rawData),
    };
  }

  factory SkuItem.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedRaw = {};
    if (map['raw_data_json'] != null && (map['raw_data_json'] as String).isNotEmpty) {
      try {
        parsedRaw = jsonDecode(map['raw_data_json'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    return SkuItem(
      id: map['id'] as int?,
      barcode: map['raw_barcode'] as String? ?? map['barcode'] as String? ?? '',
      title: map['title'] as String? ?? 'Unnamed Item',
      category: map['category'] as String? ?? '',
      originalPrice: (map['original_price'] as num?)?.toDouble(),
      discountPrice: (map['discount_price'] as num?)?.toDouble(),
      locationNotes: map['location_notes'] as String? ?? '',
      isMarkedFound: (map['is_marked_found'] as int? ?? 0) == 1,
      markedAt: map['marked_at'] != null ? DateTime.tryParse(map['marked_at'] as String) : null,
      rawData: parsedRaw,
    );
  }

  SkuItem copyWith({
    int? id,
    String? barcode,
    String? title,
    String? category,
    double? originalPrice,
    double? discountPrice,
    String? locationNotes,
    bool? isMarkedFound,
    DateTime? markedAt,
    Map<String, dynamic>? rawData,
  }) {
    return SkuItem(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      title: title ?? this.title,
      category: category ?? this.category,
      originalPrice: originalPrice ?? this.originalPrice,
      discountPrice: discountPrice ?? this.discountPrice,
      locationNotes: locationNotes ?? this.locationNotes,
      isMarkedFound: isMarkedFound ?? this.isMarkedFound,
      markedAt: markedAt ?? this.markedAt,
      rawData: rawData ?? this.rawData,
    );
  }
}
