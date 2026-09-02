import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sku_item.dart';
import '../providers/sku_provider.dart';
import '../services/audio_feedback_service.dart';

class ScanResultDialog extends StatefulWidget {
  final String barcode;
  final SkuItem? item;
  final VoidCallback onScanNext;

  const ScanResultDialog({
    super.key,
    required this.barcode,
    this.item,
    required this.onScanNext,
  });

  static Future<void> show(
    BuildContext context, {
    required String barcode,
    required SkuItem? item,
    required VoidCallback onScanNext,
  }) {
    if (item != null) {
      AudioFeedbackService.playMatchFound();
    } else {
      AudioFeedbackService.playNoMatch();
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ScanResultDialog(
        barcode: barcode,
        item: item,
        onScanNext: onScanNext,
      ),
    );
  }

  @override
  State<ScanResultDialog> createState() => _ScanResultDialogState();
}

class _ScanResultDialogState extends State<ScanResultDialog> {
  late SkuItem? _currentItem;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
  }

  Future<void> _toggleMark() async {
    if (_currentItem == null) return;
    setState(() {
      _isToggling = true;
    });

    final provider = Provider.of<SkuProvider>(context, listen: false);
    final updated = await provider.toggleMarkedFound(_currentItem!);

    if (mounted) {
      setState(() {
        _currentItem = updated ?? _currentItem?.copyWith(isMarkedFound: !_currentItem!.isMarkedFound);
        _isToggling = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMatch = _currentItem != null;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: isMatch ? Colors.green.shade700 : Colors.amber.shade800,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Icon(
                  isMatch ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMatch ? 'MATCH FOUND IN LIST' : 'NOT ON DISCOUNT LIST',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Barcode: ${widget.barcode}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onScanNext();
                  },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: isMatch ? _buildMatchDetails(context) : _buildNoMatchDetails(context),
          ),

          // Bottom Action Button (SafeArea protected from Android nav bar)
          SafeArea(
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMatch ? Colors.green.shade800 : Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text(
                  'SCAN NEXT ITEM',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onScanNext();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMatchDetails(BuildContext context) {
    final item = _currentItem!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          item.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Category & Location Pills
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (item.category.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.category, size: 16, color: Colors.teal),
                label: Text(item.category),
                backgroundColor: Colors.teal.shade50,
                side: BorderSide(color: Colors.teal.shade200),
                visualDensity: VisualDensity.compact,
              ),
            if (item.locationNotes.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.place, size: 16, color: Colors.indigo),
                label: Text(item.locationNotes),
                backgroundColor: Colors.indigo.shade50,
                side: BorderSide(color: Colors.indigo.shade200),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),

        const SizedBox(height: 16),

        // Pricing Container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PROMO / DISCOUNT PRICE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.discountPrice != null
                        ? '\$${item.discountPrice!.toStringAsFixed(2)}'
                        : 'DISCOUNTED',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
              if (item.originalPrice != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'ORIGINAL PRICE',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${item.originalPrice!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      ),
                    ),
                    if (item.savingsAmount != null && item.savingsAmount! > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Save \$${item.savingsAmount!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Mark Found Action Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: item.isMarkedFound ? Colors.green.shade100 : Colors.white,
            side: BorderSide(
              color: item.isMarkedFound ? Colors.green.shade700 : Colors.grey.shade400,
              width: 2,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _isToggling
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(
                  item.isMarkedFound ? Icons.check_box : Icons.check_box_outline_blank,
                  color: item.isMarkedFound ? Colors.green.shade800 : Colors.grey.shade800,
                  size: 24,
                ),
          label: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.isMarkedFound ? 'ISOLATED / MARKED AS FOUND' : 'MARK ITEM AS FOUND',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: item.isMarkedFound ? Colors.green.shade900 : Colors.grey.shade900,
                ),
              ),
              if (item.isMarkedFound)
                const Icon(Icons.verified, color: Colors.green, size: 20),
            ],
          ),
          onPressed: _isToggling ? null : _toggleMark,
        ),
      ],
    );
  }

  Widget _buildNoMatchDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.search_off_rounded, size: 56, color: Colors.amber),
        const SizedBox(height: 12),
        const Text(
          'Item Not Listed in Discount File',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Barcode "${widget.barcode}" was not found in the currently loaded store spreadsheet.',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Verify item tag or check if an updated Excel/CSV file needs to be imported.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
