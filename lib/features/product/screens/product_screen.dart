import 'package:flutter/material.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/barcode_scanner.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/product_service.dart';
import '../services/category_service.dart';
import '../widgets/barcode_groups_accordion.dart';
import '../widgets/product_search_dialog.dart';
import 'price_history_screen.dart';

class ProductScreen extends StatefulWidget {
  /// Ürün listesinden açılırken doğrudan productId ile yükler
  final int? initialProductId;

  /// Stok ekranından veya dışarıdan barkod ile yeni ürün formunu açar
  final String? initialBarcode;

  const ProductScreen({
    super.key,
    this.initialProductId,
    this.initialBarcode,
  });

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  bool _isLoading = false;
  Product? _product;
  String? _scannedBarcode;

  // Fiyat editleri
  final Map<String, Map<String, double?>> _priceEdits = {};

  // ─── Ortak form controller'ları ────────────────────────────────────────────
  final _barcodeCtrl = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _unitCtrl    = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _markaCtrl   = TextEditingController();
  int _selectedKdv   = 20;

  // ─── Kategori dropdown state ───────────────────────────────────────────────
  List<Category> _categories       = [];
  bool _categoriesLoading          = true;
  String? _selectedKategoriName;
  String? _selectedAltKategoriName;

  // ─── Paketlenme şekilleri — YENİ ürün oluşturma formu ────────────────────
  List<_PackagingEntry> _packagingRows = [];

  // ─── Mevcut ürüne yeni birim/barkod ekleme ────────────────────────────────
  List<_PackagingEntry> _existingProductNewRows = [];

  bool _showManualForm = false;
  bool _showInfoForm   = false;

  static const List<int> _kdvOranlari = [1, 10, 20];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.initialProductId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        setState(() => _isLoading = true);
        final product = await ProductService.getByProductId(widget.initialProductId!);
        if (mounted) {
          setState(() => _isLoading = false);
          if (product != null) _setProduct(product, null);
        }
      });
    } else if (widget.initialBarcode != null) {
      // Dışarıdan barkod geldi → yeni ürün formunu aç
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initNewProductForm(widget.initialBarcode!);
      });
    }
  }

  Future<void> _loadCategories() async {
    final cats = await CategoryService.getCategories();
    if (mounted) {
      setState(() {
        _categories         = cats;
        _categoriesLoading  = false;
      });
    }
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _contentCtrl.dispose();
    _markaCtrl.dispose();
    for (final r in _packagingRows) r.dispose();
    for (final r in _existingProductNewRows) r.dispose();
    super.dispose();
  }

  // ─── Barkod tarandığında ───────────────────────────────────────────────────

  Future<void> _onBarcodeScanned(String barcode) async {
    logger.i('Barcode scanned: $barcode');
    setState(() => _isLoading = true);

    final product = await ProductService.getByBarcode(barcode);
    setState(() => _isLoading = false);

    if (product != null) {
      _setProduct(product, barcode);
      return;
    }

    if (!mounted) return;
    final choice = await _showNotFoundDialog(barcode);

    if (choice == _Choice.newProduct) {
      _initNewProductForm(barcode);
    } else if (choice == _Choice.addToExisting) {
      final found = await ProductSearchDialog.show(context, missingBarcode: barcode);
      if (found != null) {
        setState(() => _isLoading = true);
        final refreshed = await ProductService.getByProductId(found.productId);
        setState(() => _isLoading = false);
        if (refreshed != null) _setProduct(refreshed, barcode);
      }
    } else {
      _clearAll();
    }
  }

  Future<_Choice?> _showNotFoundDialog(String barcode) {
    return showDialog<_Choice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ürün Bulunamadı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Barkod $barcode sistemde kayıtlı değil.\nNe yapmak istersiniz?',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(_Choice.newProduct),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Yeni Ürün Oluştur'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(_Choice.addToExisting),
              icon: const Icon(Icons.link),
              label: const Text('Mevcut Ürüne Ekle'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('İptal'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Yeni ürün formunu başlat ─────────────────────────────────────────────

  void _initNewProductForm(String barcode) {
    _barcodeCtrl.text = barcode;
    for (final r in _packagingRows) r.dispose();
    setState(() {
      _product                = null;
      _scannedBarcode         = barcode;
      _showManualForm         = true;
      _showInfoForm           = false;
      _nameCtrl.clear();
      _unitCtrl.text          = 'ADT';
      _contentCtrl.clear();
      _markaCtrl.clear();
      _selectedKategoriName    = null;
      _selectedAltKategoriName = null;
      _selectedKdv            = 20;
      _packagingRows          = [_PackagingEntry(unitType: 'ADT', barcode: barcode)];
    });
  }

  void _setProduct(Product product, String? barcode) {
    _barcodeCtrl.text = barcode ?? '';
    for (final r in _existingProductNewRows) r.dispose();
    setState(() {
      _product                = product;
      _scannedBarcode         = barcode;
      _showManualForm         = false;
      _showInfoForm           = false;
      _priceEdits.clear();
      _existingProductNewRows  = [];
      // Form alanları
      _nameCtrl.text          = product.productName;
      _unitCtrl.text          = product.unit;
      _contentCtrl.text       = product.content ?? '';
      _markaCtrl.text         = product.marka ?? '';
      _selectedKategoriName    = product.kategori;
      _selectedAltKategoriName = product.altKategori;
      _selectedKdv            = product.kdvOrani;
      // Fiyat önizlemesi
      for (final g in product.barcodeGroups) {
        _priceEdits[g.unitType] = {
          'alis': g.alisFiyati,
          'satis': g.satisFiyati,
        };
      }
    });
  }

  void _clearAll() {
    _barcodeCtrl.clear();
    for (final r in _packagingRows) r.dispose();
    for (final r in _existingProductNewRows) r.dispose();
    setState(() {
      _product                = null;
      _scannedBarcode         = null;
      _showManualForm         = false;
      _showInfoForm           = false;
      _priceEdits.clear();
      _selectedKategoriName    = null;
      _selectedAltKategoriName = null;
      _packagingRows           = [];
      _existingProductNewRows  = [];
    });
  }

  void _onPriceChanged(String unitType, double? alis, double? satis) {
    _priceEdits[unitType] = {'alis': alis, 'satis': satis};
  }

  // ─── Barkod sil ──────────────────────────────────────────────────────────

  Future<void> _onDeleteBarcode(String barcode, String unitType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Barkod Sil'),
        content: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              const TextSpan(text: 'Bu barkodu üründen kaldırmak istediğinize emin misiniz?\n\n'),
              TextSpan(
                text: barcode,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
              TextSpan(text: '  ($unitType)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    final ok = await ProductService.deleteBarcode(_product!.productId, barcode);
    if (!mounted) return;

    if (ok) {
      // Ürünü yenile
      final refreshed = await ProductService.getByProductId(_product!.productId);
      setState(() => _isLoading = false);
      if (refreshed != null) _setProduct(refreshed, _scannedBarcode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barkod silindi: $barcode')),
      );
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barkod silinemedi.')),
      );
    }
  }

  // ─── Birleşik kaydet (bilgi + fiyat + yeni barkodlar) ────────────────────

  Future<void> _saveAll() async {
    if (_product == null) return;
    setState(() => _isLoading = true);

    bool ok = true;

    // 1. Ürün bilgisi (form açıksa)
    if (_showInfoForm) {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ürün adı boş bırakılamaz.')),
        );
        setState(() => _isLoading = false);
        return;
      }
      ok = await ProductService.updateProduct(
        productId:   _product!.productId,
        productName: name,
        unit:        _unitCtrl.text.trim().isNotEmpty ? _unitCtrl.text.trim() : 'ADT',
        content:     _contentCtrl.text.trim().isNotEmpty ? _contentCtrl.text.trim() : null,
        marka:       _markaCtrl.text.trim().isNotEmpty ? _markaCtrl.text.trim() : null,
        kategori:    _selectedKategoriName,
        altKategori: _selectedAltKategoriName,
        kdvOrani:    _selectedKdv,
      );
    }

    // 2. Fiyatlar
    final pricesToSave = _priceEdits.entries
        .where((e) => e.value['alis'] != null || e.value['satis'] != null)
        .map((e) => {
              'unitType':    e.key,
              'alisFiyati':  e.value['alis'] ?? 0.0,
              'satisFiyati': e.value['satis'] ?? 0.0,
            })
        .toList();

    if (pricesToSave.isNotEmpty) {
      final priceOk = await ProductService.savePrices(_product!.productId, pricesToSave);
      ok = ok && priceOk;
    }

    // 3. Yeni birim/barkodlar (mevcut ürüne ekleme)
    for (final row in _existingProductNewRows) {
      final barcode = row.barcodeCtrl.text.trim();
      if (barcode.isEmpty) continue;
      final added = await ProductService.addBarcode(
        _product!.productId, barcode, row.unitType,
        unitQuantity: row.unitQuantity,
      );
      if (!added) ok = false;
    }

    final refreshed = await ProductService.getByProductId(_product!.productId);
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Kaydedildi.' : 'Kayıt sırasında hata oluştu.')),
      );
      if (refreshed != null) {
        _setProduct(refreshed, _scannedBarcode);
      }
    }
  }

  // ─── Manuel ürün oluştur ──────────────────────────────────────────────────

  Future<void> _createManualProduct() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ürün adı zorunludur.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final newId = await ProductService.createProduct(
      productName: name,
      unit:        _unitCtrl.text.trim().isNotEmpty ? _unitCtrl.text.trim() : 'ADT',
      content:     _contentCtrl.text.trim().isNotEmpty ? _contentCtrl.text.trim() : null,
      kdvOrani:    _selectedKdv,
      marka:       _markaCtrl.text.trim().isNotEmpty ? _markaCtrl.text.trim() : null,
      kategori:    _selectedKategoriName,
      altKategori: _selectedAltKategoriName,
    );

    if (newId == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ürün oluşturulamadı.')),
        );
      }
      return;
    }

    for (final row in _packagingRows) {
      final barcode = row.barcodeCtrl.text.trim();
      if (barcode.isNotEmpty) {
        await ProductService.addBarcode(
          newId, barcode, row.unitType,
          unitQuantity: row.unitQuantity,
        );
      }
    }

    final firstBarcode = _packagingRows.isNotEmpty
        ? _packagingRows[0].barcodeCtrl.text.trim()
        : null;
    final product = await ProductService.getByProductId(newId);
    setState(() => _isLoading = false);

    if (product != null) {
      _setProduct(product,
          firstBarcode != null && firstBarcode.isNotEmpty ? firstBarcode : null);
    } else {
      for (final r in _packagingRows) r.dispose();
      setState(() {
        _packagingRows  = [];
        _showManualForm = false;
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ürün oluşturuldu: #$newId')),
      );
    }
  }

  // ─── Yeni ürün — paketleme satırı callback'leri ──────────────────────────

  void _onPackagingUnitTypeChanged(int index, String newType) {
    setState(() => _packagingRows[index].unitType = newType);
  }

  void _onPackagingRowRemoved(int index) {
    final removed = _packagingRows[index];
    setState(() => _packagingRows.removeAt(index));
    removed.dispose();
  }

  void _onAddPackagingRow() {
    setState(() => _packagingRows.add(_PackagingEntry()));
  }

  Future<void> _onScanPackagingBarcode(int index) async {
    final barcode = await BarcodeScannerScreen.scan(context);
    if (barcode != null && mounted) {
      setState(() => _packagingRows[index].barcodeCtrl.text = barcode);
    }
  }

  // ─── Mevcut ürün — yeni birim/barkod satırı callback'leri ────────────────

  void _onExistingUnitTypeChanged(int index, String newType) {
    setState(() => _existingProductNewRows[index].unitType = newType);
  }

  void _onExistingRowRemoved(int index) {
    final removed = _existingProductNewRows[index];
    setState(() => _existingProductNewRows.removeAt(index));
    removed.dispose();
  }

  void _onAddExistingRow() {
    setState(() => _existingProductNewRows.add(_PackagingEntry()));
  }

  Future<void> _onScanExistingBarcode(int index) async {
    final barcode = await BarcodeScannerScreen.scan(context);
    if (barcode != null && mounted) {
      setState(() => _existingProductNewRows[index].barcodeCtrl.text = barcode);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün / Fiyat'),
        actions: [
          if (_product != null)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Fiyat Geçmişi',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PriceHistoryScreen(
                    productId:   _product!.productId,
                    productName: _product!.productName,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Barkod tarayıcı ──────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _barcodeCtrl,
                          autofocus: false,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            labelText: 'Barkod',
                            hintText: 'Okut veya elle gir…',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (v) {
                            final barcode = v.trim();
                            if (barcode.isNotEmpty) _onBarcodeScanned(barcode);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, size: 32),
                        onPressed: () async {
                          final barcode = await BarcodeScannerScreen.scan(context);
                          if (barcode != null) await _onBarcodeScanned(barcode);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── Mevcut ürün ──────────────────────────────────────
                  if (_product != null) ...[
                    _ProductInfoExpander(
                      product:                 _product!,
                      isExpanded:              _showInfoForm,
                      onToggle:                () => setState(() => _showInfoForm = !_showInfoForm),
                      nameCtrl:                _nameCtrl,
                      unitCtrl:                _unitCtrl,
                      contentCtrl:             _contentCtrl,
                      markaCtrl:               _markaCtrl,
                      selectedKdv:             _selectedKdv,
                      kdvOranlari:             _kdvOranlari,
                      onKdvChanged:            (v) => setState(() => _selectedKdv = v!),
                      categories:              _categories,
                      categoriesLoading:       _categoriesLoading,
                      selectedKategoriName:    _selectedKategoriName,
                      selectedAltKategoriName: _selectedAltKategoriName,
                      onKategoriChanged: (v) => setState(() {
                        _selectedKategoriName    = v;
                        _selectedAltKategoriName = null;
                      }),
                      onAltKategoriChanged: (v) => setState(() => _selectedAltKategoriName = v),
                    ),
                    const SizedBox(height: 12),

                    BarcodeGroupsAccordion(
                      barcodeGroups:    _product!.barcodeGroups,
                      showPriceFields:  true,
                      onPriceChanged:   _onPriceChanged,
                      onDeleteBarcode:  _onDeleteBarcode,
                    ),
                    const SizedBox(height: 12),

                    // ─── Mevcut ürüne yeni birim / barkod ekleme ──────
                    if (_existingProductNewRows.isEmpty)
                      OutlinedButton.icon(
                        onPressed: _onAddExistingRow,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Yeni Birim Tipi / Barkod Ekle'),
                      )
                    else ...[
                      _SectionHeader(title: 'Yeni Barkod Ekle'),
                      const SizedBox(height: 8),
                      _PackagingSection(
                        rows:              _existingProductNewRows,
                        onUnitTypeChanged: _onExistingUnitTypeChanged,
                        onRemoveRow:       _onExistingRowRemoved,
                        onAddRow:          _onAddExistingRow,
                        onScanBarcode:     _onScanExistingBarcode,
                      ),
                    ],
                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      onPressed: _saveAll,
                      icon: const Icon(Icons.save),
                      label: Text(_showInfoForm
                          ? 'Bilgi & Fiyatları Kaydet'
                          : (_existingProductNewRows.isNotEmpty
                              ? 'Fiyat & Barkodları Kaydet'
                              : 'Fiyatları Kaydet')),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text('Temizle'),
                    ),
                  ],

                  // ─── Yeni ürün formu ──────────────────────────────────
                  if (_showManualForm) ...[
                    _SectionHeader(title: 'Temel Bilgiler'),
                    const SizedBox(height: 12),
                    _ProductFormFields(
                      nameCtrl:                _nameCtrl,
                      unitCtrl:                _unitCtrl,
                      contentCtrl:             _contentCtrl,
                      markaCtrl:               _markaCtrl,
                      selectedKdv:             _selectedKdv,
                      kdvOranlari:             _kdvOranlari,
                      onKdvChanged:            (v) => setState(() => _selectedKdv = v!),
                      categories:              _categories,
                      categoriesLoading:       _categoriesLoading,
                      selectedKategoriName:    _selectedKategoriName,
                      selectedAltKategoriName: _selectedAltKategoriName,
                      onKategoriChanged: (v) => setState(() {
                        _selectedKategoriName    = v;
                        _selectedAltKategoriName = null;
                      }),
                      onAltKategoriChanged: (v) => setState(() => _selectedAltKategoriName = v),
                    ),
                    const SizedBox(height: 20),

                    _SectionHeader(title: 'Paketlenme Şekilleri'),
                    const SizedBox(height: 12),
                    _PackagingSection(
                      rows:              _packagingRows,
                      onUnitTypeChanged: _onPackagingUnitTypeChanged,
                      onRemoveRow:       _onPackagingRowRemoved,
                      onAddRow:          _onAddPackagingRow,
                      onScanBarcode:     _onScanPackagingBarcode,
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      onPressed: _createManualProduct,
                      icon: const Icon(Icons.add),
                      label: const Text('Ürünü Oluştur'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text('İptal'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ─── Paketleme satırı veri sınıfı ─────────────────────────────────────────

class _PackagingEntry {
  String unitType;
  final TextEditingController barcodeCtrl;
  final TextEditingController quantityCtrl;

  _PackagingEntry({this.unitType = 'ADT', String? barcode})
      : barcodeCtrl  = TextEditingController(text: barcode ?? ''),
        quantityCtrl = TextEditingController();

  void dispose() {
    barcodeCtrl.dispose();
    quantityCtrl.dispose();
  }

  double? get unitQuantity {
    final v = double.tryParse(quantityCtrl.text.trim());
    return (v != null && v > 1) ? v : null;
  }
}

// ─── Bölüm başlığı ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }
}

// ─── Paketlenme şekilleri bölümü ──────────────────────────────────────────

class _PackagingSection extends StatelessWidget {
  final List<_PackagingEntry> rows;
  final void Function(int index, String newType) onUnitTypeChanged;
  final void Function(int index) onRemoveRow;
  final VoidCallback onAddRow;
  final void Function(int index) onScanBarcode;

  static const _unitTypes      = ['ADT', 'KL', 'PAK', 'KG', 'GR', 'L', 'ML', 'BX'];
  static const _multipackTypes = {'KL', 'PAK', 'BX'};

  const _PackagingSection({
    required this.rows,
    required this.onUnitTypeChanged,
    required this.onRemoveRow,
    required this.onAddRow,
    required this.onScanBarcode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...rows.asMap().entries.map((e) => _buildRow(context, e.key, e.value)),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: onAddRow,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Yeni Birim Tipi Ekle'),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, int i, _PackagingEntry entry) {
    final showQty = _multipackTypes.contains(entry.unitType);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 74,
            child: DropdownButtonFormField<String>(
              value: entry.unitType,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              ),
              items: _unitTypes
                  .map((u) => DropdownMenuItem(
                      value: u, child: Text(u, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) => onUnitTypeChanged(i, v!),
            ),
          ),
          if (showQty) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 58,
              child: TextField(
                controller: entry.quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Adet',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: entry.barcodeCtrl,
              decoration: const InputDecoration(
                labelText: 'Barkod',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, size: 22),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints(),
            onPressed: () => onScanBarcode(i),
          ),
          if (rows.length > 1)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(),
              onPressed: () => onRemoveRow(i),
            ),
        ],
      ),
    );
  }
}

// ─── Tıklanabilir ürün bilgi kartı ────────────────────────────────────────

class _ProductInfoExpander extends StatelessWidget {
  final Product product;
  final bool isExpanded;
  final VoidCallback onToggle;
  final TextEditingController nameCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController contentCtrl;
  final TextEditingController markaCtrl;
  final int selectedKdv;
  final List<int> kdvOranlari;
  final ValueChanged<int?> onKdvChanged;
  final List<Category> categories;
  final bool categoriesLoading;
  final String? selectedKategoriName;
  final String? selectedAltKategoriName;
  final ValueChanged<String?> onKategoriChanged;
  final ValueChanged<String?> onAltKategoriChanged;

  const _ProductInfoExpander({
    required this.product,
    required this.isExpanded,
    required this.onToggle,
    required this.nameCtrl,
    required this.unitCtrl,
    required this.contentCtrl,
    required this.markaCtrl,
    required this.selectedKdv,
    required this.kdvOranlari,
    required this.onKdvChanged,
    required this.categories,
    required this.categoriesLoading,
    required this.selectedKategoriName,
    required this.selectedAltKategoriName,
    required this.onKategoriChanged,
    required this.onAltKategoriChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          InkWell(
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(10))
                : BorderRadius.circular(10),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (product.marka != null) _Chip(product.marka!, Colors.blue),
                            if (product.kategori != null) _Chip(product.kategori!, Colors.green),
                            _Chip('KDV %${product.kdvOrani}', Colors.grey),
                            _Chip('#${product.productId}', Colors.blueGrey),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.edit_outlined,
                    color: Colors.blueGrey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _ProductFormFields(
                nameCtrl:                nameCtrl,
                unitCtrl:                unitCtrl,
                contentCtrl:             contentCtrl,
                markaCtrl:               markaCtrl,
                selectedKdv:             selectedKdv,
                kdvOranlari:             kdvOranlari,
                onKdvChanged:            onKdvChanged,
                categories:              categories,
                categoriesLoading:       categoriesLoading,
                selectedKategoriName:    selectedKategoriName,
                selectedAltKategoriName: selectedAltKategoriName,
                onKategoriChanged:       onKategoriChanged,
                onAltKategoriChanged:    onAltKategoriChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Ortak form alanları widget'ı ─────────────────────────────────────────

class _ProductFormFields extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController contentCtrl;
  final TextEditingController markaCtrl;
  final int selectedKdv;
  final List<int> kdvOranlari;
  final ValueChanged<int?> onKdvChanged;
  final List<Category> categories;
  final bool categoriesLoading;
  final String? selectedKategoriName;
  final String? selectedAltKategoriName;
  final ValueChanged<String?> onKategoriChanged;
  final ValueChanged<String?> onAltKategoriChanged;

  const _ProductFormFields({
    required this.nameCtrl,
    required this.unitCtrl,
    required this.contentCtrl,
    required this.markaCtrl,
    required this.selectedKdv,
    required this.kdvOranlari,
    required this.onKdvChanged,
    required this.categories,
    required this.categoriesLoading,
    required this.selectedKategoriName,
    required this.selectedAltKategoriName,
    required this.onKategoriChanged,
    required this.onAltKategoriChanged,
  });

  Category? _findCategory(String? name) {
    if (name == null) return null;
    try {
      return categories.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  List<DropdownMenuItem<String?>> _kategoriItems() {
    final items = <DropdownMenuItem<String?>>[];
    items.add(const DropdownMenuItem<String?>(
        value: null,
        child: Text('Seçiniz...', style: TextStyle(color: Colors.grey))));
    final names = <String>{};
    for (final c in categories) {
      names.add(c.name);
      items.add(DropdownMenuItem<String?>(value: c.name, child: Text(c.name)));
    }
    if (selectedKategoriName != null && !names.contains(selectedKategoriName)) {
      items.add(DropdownMenuItem<String?>(
          value: selectedKategoriName, child: Text(selectedKategoriName!)));
    }
    return items;
  }

  List<DropdownMenuItem<String?>> _altKategoriItems() {
    final items = <DropdownMenuItem<String?>>[];
    items.add(const DropdownMenuItem<String?>(
        value: null,
        child: Text('Seçiniz...', style: TextStyle(color: Colors.grey))));
    final selectedCat = _findCategory(selectedKategoriName);
    if (selectedCat != null) {
      final names = <String>{};
      for (final s in selectedCat.subCategories) {
        names.add(s.name);
        items.add(DropdownMenuItem<String?>(value: s.name, child: Text(s.name)));
      }
      if (selectedAltKategoriName != null && !names.contains(selectedAltKategoriName)) {
        items.add(DropdownMenuItem<String?>(
            value: selectedAltKategoriName, child: Text(selectedAltKategoriName!)));
      }
    } else if (selectedAltKategoriName != null) {
      items.add(DropdownMenuItem<String?>(
          value: selectedAltKategoriName, child: Text(selectedAltKategoriName!)));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final selectedCat = _findCategory(selectedKategoriName);
    final hasAltKat   = selectedCat != null && selectedCat.subCategories.isNotEmpty;

    return Column(
      children: [
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Ürün Adı *',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Birim (ADT, KG...)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: selectedKdv,
                decoration: const InputDecoration(
                  labelText: 'KDV %',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: kdvOranlari
                    .map((k) => DropdownMenuItem(value: k, child: Text('%$k')))
                    .toList(),
                onChanged: onKdvChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: markaCtrl,
          decoration: const InputDecoration(
            labelText: 'Marka',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        if (categoriesLoading)
          const LinearProgressIndicator()
        else
          DropdownButtonFormField<String?>(
            value: selectedKategoriName,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _kategoriItems(),
            onChanged: onKategoriChanged,
          ),
        if (!categoriesLoading && (hasAltKat || selectedAltKategoriName != null)) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            value: selectedAltKategoriName,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Alt Kategori',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _altKategoriItems(),
            onChanged: onAltKategoriChanged,
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: contentCtrl,
          decoration: const InputDecoration(
            labelText: 'İçerik / Açıklama',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ─── Chip yardımcısı ──────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color.withOpacity(0.9)),
      ),
    );
  }
}

enum _Choice { newProduct, addToExisting }
