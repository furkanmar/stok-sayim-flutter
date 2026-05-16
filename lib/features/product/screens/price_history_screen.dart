import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/product_service.dart';

class PriceHistoryScreen extends StatefulWidget {
  final int productId;
  final String productName;

  const PriceHistoryScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends State<PriceHistoryScreen> {
  List<ProductPriceEntry> _entries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ProductService.getPriceHistory(widget.productId);
      // Tarihe göre azalan sırala
      data.sort((a, b) => b.gecerlilikTarihi.compareTo(a.gecerlilikTarihi));
      setState(() => _entries = data);
    } catch (e) {
      setState(() => _error = 'Fiyat geçmişi yüklenemedi.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Benzersiz unitType listesi (ilk görülme sırasına göre korunur)
  List<String> get _unitTypes {
    final seen = <String>{};
    return _entries
        .map((e) => e.unitType)
        .where((t) => seen.add(t))
        .toList();
  }

  List<ProductPriceEntry> _entriesFor(String unitType) =>
      _entries.where((e) => e.unitType == unitType).toList();

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fiyat Geçmişi', style: TextStyle(fontSize: 16)),
            Text(
              widget.productName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Tekrar Dene')),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return const Center(
        child: Text(
          'Bu ürün için fiyat geçmişi bulunamadı.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final unitTypes = _unitTypes;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: unitTypes.length,
      itemBuilder: (context, i) {
        final unitType = unitTypes[i];
        final entries = _entriesFor(unitType);
        return _UnitTypeSection(
          unitType: unitType,
          entries: entries,
          formatDate: _formatDate,
        );
      },
    );
  }
}

class _UnitTypeSection extends StatelessWidget {
  final String unitType;
  final List<ProductPriceEntry> entries;
  final String Function(DateTime) formatDate;

  const _UnitTypeSection({
    required this.unitType,
    required this.entries,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Chip(
          label: Text(
            unitType,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        title: Text(
          '${entries.length} kayıt',
          style: const TextStyle(fontSize: 14),
        ),
        children: [
          // Başlık satırı
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text('Tarih', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Text('Alış', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Text('Satış', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Text('Marj', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          ...entries.asMap().entries.map((e) {
            final idx = e.key;
            final entry = e.value;
            final kar = entry.satisFiyati - entry.alisFiyati;
            final marj = entry.alisFiyati > 0
                ? (kar / entry.alisFiyati * 100)
                : 0.0;
            final isLatest = idx == 0;

            return Container(
              decoration: BoxDecoration(
                color: isLatest
                    ? Colors.blue.shade50
                    : (idx.isEven ? Colors.white : Colors.grey.shade50),
                border: isLatest
                    ? Border(left: BorderSide(color: Colors.blue, width: 3))
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatDate(entry.gecerlilikTarihi),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (isLatest)
                          const Text(
                            'Güncel',
                            style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${entry.alisFiyati.toStringAsFixed(2)} ₺',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${entry.satisFiyati.toStringAsFixed(2)} ₺',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '%${marj.toStringAsFixed(1)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                        color: marj >= 0 ? Colors.green.shade700 : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
