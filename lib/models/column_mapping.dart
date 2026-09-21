class ColumnMapping {
  int barcodeColIndex;
  int titleColIndex;
  int categoryColIndex;
  int originalPriceColIndex;
  int discountPriceColIndex;
  int locationNotesColIndex;
  bool forceGeneralMode;

  ColumnMapping({
    this.barcodeColIndex = 0,
    this.titleColIndex = -1,
    this.categoryColIndex = -1,
    this.originalPriceColIndex = -1,
    this.discountPriceColIndex = -1,
    this.locationNotesColIndex = -1,
    this.forceGeneralMode = false,
  });

  bool get isValid => barcodeColIndex >= 0;

  bool get isDiscountMode => !forceGeneralMode && (discountPriceColIndex >= 0 || originalPriceColIndex >= 0);

  /// Attempt auto-detection of column indices based on header names and sample rows.
  factory ColumnMapping.autoDetect(List<String> headers, {List<List<dynamic>>? sampleRows}) {
    int barcodeIdx = -1;
    int titleIdx = -1;
    int categoryIdx = -1;
    int origPriceIdx = -1;
    int discPriceIdx = -1;
    int notesIdx = -1;

    for (int i = 0; i < headers.length; i++) {
      String h = headers[i].trim().toLowerCase();

      if (barcodeIdx == -1 &&
          (h.contains('barcode') ||
           h.contains('sku') ||
           h.contains('upc') ||
           h.contains('ean') ||
           h.contains('item #') ||
           h.contains('item_num') ||
           h.contains('item code') ||
           h.contains('part #') ||
           h.contains('id') ||
           h.contains('code'))) {
        barcodeIdx = i;
      } else if (titleIdx == -1 &&
          (h.contains('desc') ||
           h.contains('title') ||
           h.contains('name') ||
           h.contains('product') ||
           h.contains('item'))) {
        titleIdx = i;
      } else if (categoryIdx == -1 &&
          (h.contains('cat') ||
           h.contains('dept') ||
           h.contains('department') ||
           h.contains('group') ||
           h.contains('class'))) {
        categoryIdx = i;
      } else if (discPriceIdx == -1 &&
          (h.contains('promo') ||
           h.contains('sale') ||
           h.contains('disc') ||
           h.contains('deal') ||
           h.contains('offer') ||
           h.contains('final'))) {
        discPriceIdx = i;
      } else if (origPriceIdx == -1 &&
          (h.contains('price') ||
           h.contains('msrp') ||
           h.contains('cost') ||
           h.contains('orig') ||
           h.contains('retail') ||
           h.contains('was'))) {
        origPriceIdx = i;
      } else if (notesIdx == -1 &&
          (h.contains('location') ||
           h.contains('aisle') ||
           h.contains('shelf') ||
           h.contains('note') ||
           h.contains('bin') ||
           h.contains('rack') ||
           h.contains('qty') ||
           h.contains('stock'))) {
        notesIdx = i;
      }
    }

    // Fallback: If no barcode header matched, inspect sample rows for numeric strings
    if (barcodeIdx == -1 && sampleRows != null && sampleRows.isNotEmpty) {
      for (int c = 0; c < headers.length; c++) {
        for (final row in sampleRows) {
          if (c < row.length) {
            String val = row[c]?.toString().trim() ?? '';
            if (RegExp(r'^\d{6,14}$').hasMatch(val)) {
              barcodeIdx = c;
              break;
            }
          }
        }
        if (barcodeIdx != -1) break;
      }
    }

    // Ultimate fallback: column 0 if headers exist
    if (barcodeIdx == -1 && headers.isNotEmpty) {
      barcodeIdx = 0;
    }

    // Fallbacks if price columns overlap
    if (origPriceIdx != -1 && discPriceIdx == origPriceIdx) {
      discPriceIdx = -1;
    }

    return ColumnMapping(
      barcodeColIndex: barcodeIdx,
      titleColIndex: titleIdx,
      categoryColIndex: categoryIdx,
      originalPriceColIndex: origPriceIdx,
      discountPriceColIndex: discPriceIdx,
      locationNotesColIndex: notesIdx,
    );
  }
}
