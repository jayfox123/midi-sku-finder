import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sku_item.dart';
import '../providers/sku_provider.dart';
import '../services/database_service.dart';
import 'scan_result_dialog.dart';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<SkuItem> _items = [];
  bool _isLoading = true;
  bool _onlyMarked = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    final results = await _dbService.searchItems(
      query: _searchQuery,
      onlyMarked: _onlyMarked ? true : null,
      limit: 150,
    );

    if (mounted) {
      setState(() {
        _items = results;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _loadItems();
  }

  Future<void> _toggleItemMark(SkuItem item) async {
    final provider = Provider.of<SkuProvider>(context, listen: false);
    await provider.toggleMarkedFound(item);
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final skuProvider = Provider.of<SkuProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store SKUs & Marked Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by SKU barcode, title, or category...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      selected: !_onlyMarked,
                      label: Text('All SKUs (${skuProvider.totalCount})'),
                      onSelected: (val) {
                        setState(() {
                          _onlyMarked = false;
                        });
                        _loadItems();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _onlyMarked,
                      avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      label: Text('Marked Found (${skuProvider.markedCount})'),
                      onSelected: (val) {
                        setState(() {
                          _onlyMarked = true;
                        });
                        _loadItems();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Items List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _buildItemTile(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(SkuItem item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Checkbox(
        value: item.isMarkedFound,
        activeColor: Colors.green.shade700,
        onChanged: (_) => _toggleItemMark(item),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          decoration: item.isMarkedFound ? TextDecoration.lineThrough : null,
          color: item.isMarkedFound ? Colors.grey.shade600 : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            'Barcode: ${item.barcode}${item.category.isNotEmpty ? ' • ${item.category}' : ''}',
            style: const TextStyle(fontSize: 12),
          ),
          if (item.locationNotes.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Location: ${item.locationNotes}',
              style: TextStyle(fontSize: 11, color: Colors.indigo.shade700),
            ),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            item.discountPrice != null ? '\$${item.discountPrice!.toStringAsFixed(2)}' : 'N/A',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          if (item.originalPrice != null)
            Text(
              '\$${item.originalPrice!.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                decoration: TextDecoration.lineThrough,
                color: Colors.grey,
              ),
            ),
        ],
      ),
      onTap: () {
        ScanResultDialog.show(
          context,
          barcode: item.barcode,
          item: item,
          onScanNext: _loadItems,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No SKUs match "$_searchQuery"'
                  : _onlyMarked
                      ? 'No items marked as found yet.'
                      : 'No SKUs loaded in database.',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _onlyMarked
                  ? 'Scan barcodes and tap "Mark Found" to isolate physical items.'
                  : 'Import an Excel/CSV file to display products.',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
