import 'package:flutter_test/flutter_test.dart';
import 'package:midi_sku_finder/models/column_mapping.dart';
import 'package:midi_sku_finder/models/sku_item.dart';

void main() {
  group('SkuItem Normalization & Pricing Tests', () {
    test('normalizeBarcode cleans spaces, hyphens, and casing', () {
      expect(SkuItem.normalizeBarcode(' 0123-456-789 '), equals('0123456789'));
      expect(SkuItem.normalizeBarcode('upc_98765'), equals('upc98765'));
    });

    test('discountPercentage calculates correctly', () {
      final item = SkuItem(
        barcode: '123456',
        title: 'Test Shirt',
        originalPrice: 100.0,
        discountPrice: 40.0,
      );
      expect(item.discountPercentage, equals(60.0));
      expect(item.savingsAmount, equals(60.0));
    });
  });

  group('ColumnMapping Auto-Detection Tests', () {
    test('autoDetect correctly identifies standard retail headers', () {
      final headers = [
        'Item Barcode Number',
        'Product Description',
        'Dept Category',
        'Original MSRP Price',
        'Sale Promo Price',
        'Aisle Location Notes'
      ];

      final mapping = ColumnMapping.autoDetect(headers);

      expect(mapping.isValid, isTrue);
      expect(mapping.barcodeColIndex, equals(0));
      expect(mapping.titleColIndex, equals(1));
      expect(mapping.categoryColIndex, equals(2));
      expect(mapping.originalPriceColIndex, equals(3));
      expect(mapping.discountPriceColIndex, equals(4));
      expect(mapping.locationNotesColIndex, equals(5));
    });
  });
}
