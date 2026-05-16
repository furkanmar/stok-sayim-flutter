import 'package:flutter/material.dart';
import '../services/product_service.dart';
import 'product_screen.dart';

/// Salt okunur ürün listesi — iki tab: kasa fiyatlı / fiyatsız
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Listesi'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Kasa Fiyatlı'),
            Tab(text: 'Fiyatsız'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ProductTab(hasFiyat: true),
          _ProductTab(hasFiyat: false),
        ],
      ),
    );
  }
}

// ─── Tab içeriği (bağımsız state) ──────────────────────────────────────────

class _ProductTab extends StatefulWidget {
  final bool hasFiyat;
  const _ProductTab({required this.hasFiyat});

  @override
  State<_ProductTab> createState() => _ProductTabState();
}

class _ProductTabState extends State<_ProductTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();

  bool _isLoading     = false;
  bool _isLoadingMore = false;
  bool _hasMore       = true;

  int _page  = 1;
  int _total = 0;

  String? _selectedMarka;
  String? _selectedKategori;

  List<String> _markas      = [];
  List<String> _kategoriler = [];
  List<_ProductListItem> _items = [];

  @override
  bool get wantKeepAlive => true; // Tab değişince state silinmesin

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadPage(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    final results = await Future.wait([
      ProductService.getMarkas(),
      ProductService.getKategoriler(),
    ]);
    if (mounted) {
      setState(() {
        _markas      = results[0];
        _kategoriler = results[1];
      });
    }
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (reset) {
      _page    = 1;
      _items   = [];
      _hasMore = true;
    }

    if (!_hasMore || _isLoading || _isLoadingMore) return;

    setState(() => reset ? _isLoading = true : _isLoadingMore = true);

    final data = await ProductService.getProductList(
      q:        _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
      marka:    _selectedMarka,
      kategori: _selectedKategori,
      hasFiyat: widget.hasFiyat,
      page:     _page,
      pageSize: 30,
    );

    if (!mounted) return;

    if (data == null) {
      setState(() {
        _isLoading     = false;
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ürünler yüklenemedi.')),
      );
      return;
    }

    final rawItems = data['items'] as List<dynamic>;
    final newItems = rawItems
        .map((e) => _ProductListItem.fromJson(e as Map<String, dynamic>))
        .toList();

    setState(() {
      _total         = data['total'] as int? ?? 0;
      _hasMore       = data['hasMore'] as bool? ?? false;
      _items         = reset ? newItems : [..._items, ...newItems];
      _page++;
      _isLoading     = false;
      _isLoadingMore = false;
    });
  }

  void _applyFilters() => _loadPage(reset: true);

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _selectedMarka    = null;
      _selectedKategori = null;
    });
    _loadPage(reset: true);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        // ─── Arama + filtre alanı ────────────────────────────────────────
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            children: [
              // Başlık: toplam sayım + filtre temizleme
              Row(
                children: [
                  Text(
                    '$_total ürün',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  if (_selectedMarka != null || _selectedKategori != null)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off, size: 16),
                      label: const Text('Temizle',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // Arama kutusu
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Ürün adı ile ara…',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) => _applyFilters(),
                textInputAction: TextInputAction.search,
                onChanged: (v) {
                  if (v.isEmpty) _applyFilters();
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              // Marka + Kategori filtresi
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedMarka,
                      decoration: const InputDecoration(
                        labelText: 'Marka',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Tümü')),
                        ..._markas.map((m) =>
                            DropdownMenuItem(value: m, child: Text(m))),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedMarka = v);
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedKategori,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Tümü')),
                        ..._kategoriler.map((k) =>
                            DropdownMenuItem(value: k, child: Text(k))),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedKategori = v);
                        _applyFilters();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ─── Liste ──────────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Ürün bulunamadı.',
                            style:
                                TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollEndNotification &&
                            n.metrics.extentAfter < 200) {
                          _loadPage();
                        }
                        return false;
                      },
                      child: RefreshIndicator(
                        onRefresh: () => _loadPage(reset: true),
                        child: ListView.separated(
                          itemCount:
                              _items.length + (_isLoadingMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            if (i == _items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }
                            return _ProductListTile(item: _items[i]);
                          },
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ─── Liste satırı ──────────────────────────────────────────────────────────

class _ProductListTile extends StatelessWidget {
  final _ProductListItem item;
  const _ProductListTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductScreen(initialProductId: item.productId),
          ),
        );
      },
      title: Text(
        item.productName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Wrap(
          spacing: 6,
          runSpacing: 3,
          children: [
            if (item.marka != null)
              _Tag(item.marka!, Colors.blue),
            if (item.kategori != null)
              _Tag(item.kategori!, Colors.green),
            _Tag(item.unit, Colors.blueGrey),
            _Tag('${item.barcodeCount} barkod', Colors.grey),
          ],
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '#${item.productId}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          if (item.satisFiyati != null && item.satisFiyati! > 0) ...[
            const SizedBox(height: 2),
            Text(
              '${item.satisFiyati!.toStringAsFixed(2)} ₺',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Küçük etiket ─────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color.withOpacity(0.85)),
      ),
    );
  }
}

// ─── Veri modeli ──────────────────────────────────────────────────────────

class _ProductListItem {
  final int productId;
  final String productName;
  final String? marka;
  final String? kategori;
  final String unit;
  final int kdvOrani;
  final int barcodeCount;
  final double? satisFiyati;

  _ProductListItem({
    required this.productId,
    required this.productName,
    this.marka,
    this.kategori,
    required this.unit,
    required this.kdvOrani,
    required this.barcodeCount,
    this.satisFiyati,
  });

  factory _ProductListItem.fromJson(Map<String, dynamic> json) {
    return _ProductListItem(
      productId:    json['productId'] as int,
      productName:  json['productName'] ?? '',
      marka:        json['marka'] as String?,
      kategori:     json['kategori'] as String?,
      unit:         json['unit'] ?? '',
      kdvOrani:     json['kdvOrani'] as int? ?? 20,
      barcodeCount: json['barcodeCount'] as int? ?? 0,
      satisFiyati:  (json['satisFiyati'] as num?)?.toDouble(),
    );
  }
}
