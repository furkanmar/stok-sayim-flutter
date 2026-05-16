import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/barcode_scanner.dart';
import '../../home/providers/home_provider.dart';
import '../../product/models/product.dart';
import '../../product/services/product_service.dart';
import '../../product/widgets/barcode_groups_accordion.dart';
import '../../product/screens/product_screen.dart';
import '../../product/widgets/product_search_dialog.dart';
import '../models/stock_count.dart';
import '../services/stock_service.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  bool _isLoading = false;
  Product? _product;
  String? _scannedBarcode;

  StockCount? _selectedStockCount;
  List<StockCount> _activeCounts = [];

  /// unitType → baz birimde stok (koli/paket durumunda zaten çarpılmış değer)
  final Map<String, double> _stockEdits = {};

  final _barcodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadActiveCounts();
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    super.dispose();
  }

  // ─── Aktif sayımları yükle ─────────────────────────────────────────────────

  Future<void> _loadActiveCounts() async {
    final branchId = context.read<HomeProvider>().activeBranchId;
    if (branchId == null) return;

    setState(() => _isLoading = true);
    final counts = await StockService.getActiveCounts(int.parse(branchId));
    setState(() {
      _activeCounts = counts;
      _isLoading    = false;
    });
  }

  // ─── Barkod tarandığında ───────────────────────────────────────────────────

  Future<void> _onBarcodeScanned(String barcode) async {
    if (_selectedStockCount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce bir sayım seçin.')),
      );
      return;
    }

    logger.i('Barcode scanned: $barcode');
    setState(() => _isLoading = true);

    final product = await ProductService.getByBarcode(barcode);
    setState(() => _isLoading = false);

    if (product != null) {
      _setProduct(product, barcode);
      await _checkAndPromptPrice(product);
      return;
    }

    if (!mounted) return;

    // Barkod bulunamadı — ne yapılacağını sor
    final choice = await _showNotFoundDialog(barcode);

    if (choice == _StockNotFoundChoice.newProduct) {
      // Ürün ekle/değiştir ekranını yeni ürün formuyla aç
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductScreen(initialBarcode: barcode),
        ),
      );
      // Geri dönünce aynı barkodu tekrar dene (kullanıcı ürünü kaydetmiş olabilir)
      if (!mounted) return;
      setState(() => _isLoading = true);
      final created = await ProductService.getByBarcode(barcode);
      setState(() => _isLoading = false);
      if (created != null) _setProduct(created, barcode);
    } else if (choice == _StockNotFoundChoice.addToExisting) {
      final found = await ProductSearchDialog.show(context, missingBarcode: barcode);
      if (found != null) {
        setState(() => _isLoading = true);
        final refreshed = await ProductService.getByProductId(found.productId);
        setState(() => _isLoading = false);
        if (refreshed != null) _setProduct(refreshed, barcode);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Barkod ${found.productName} ürününe eklendi.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
    // İptal → hiçbir şey yapma
  }

  Future<_StockNotFoundChoice?> _showNotFoundDialog(String barcode) {
    return showDialog<_StockNotFoundChoice>(
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
              onPressed: () =>
                  Navigator.of(ctx).pop(_StockNotFoundChoice.newProduct),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Yeni Ürün Oluştur'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(ctx).pop(_StockNotFoundChoice.addToExisting),
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

  void _setProduct(Product product, String barcode) {
    _barcodeCtrl.text = barcode;
    setState(() {
      _product        = product;
      _scannedBarcode = barcode;
      _stockEdits.clear();
    });
  }

  /// Ürünün tüm barcodeGroup'larında kasa fiyatı yoksa kullanıcıya sorar.
  Future<void> _checkAndPromptPrice(Product product) async {
    final hasPrice = product.barcodeGroups
        .any((g) => (g.satisFiyati ?? 0) > 0);
    if (hasPrice) return;

    if (!mounted) return;

    final enter = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kasa Fiyatı Yok'),
        content: Text(
          '"${product.productName}" ürününün kasa fiyatı girilmemiş.\n'
          'Şimdi fiyat girmek ister misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hayır'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Evet, Fiyat Gir'),
          ),
        ],
      ),
    );

    if (enter != true || !mounted) return;
    await _showQuickPriceDialog(product);
  }

  /// Hızlı fiyat giriş dialog'u — sadece satış fiyatı, ADT birimi.
  Future<void> _showQuickPriceDialog(Product product) async {
    final satisFiyatiCtrl = TextEditingController();
    final alisFiyatiCtrl  = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Fiyat Gir',
          style: const TextStyle(fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              product.productName,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: satisFiyatiCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Satış Fiyatı (₺)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: alisFiyatiCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Alış Fiyatı (₺)  —  opsiyonel',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Atla'),
          ),
          ElevatedButton(
            onPressed: () async {
              final satis = double.tryParse(
                  satisFiyatiCtrl.text.replaceAll(',', '.'));
              if (satis == null || satis <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Geçerli bir fiyat girin.')),
                );
                return;
              }
              final alis = double.tryParse(
                      alisFiyatiCtrl.text.replaceAll(',', '.')) ??
                  0.0;

              final unitType = product.barcodeGroups.isNotEmpty
                  ? product.barcodeGroups.first.unitType
                  : 'ADT';

              final ok = await ProductService.savePrices(
                product.productId,
                [
                  {
                    'unitType': unitType,
                    'alisFiyati': alis,
                    'satisFiyati': satis,
                  }
                ],
              );
              if (ctx.mounted) Navigator.of(ctx).pop(ok);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kasa fiyatı kaydedildi.')),
      );
    }
  }

  void _clearProduct() {
    _barcodeCtrl.clear();
    setState(() {
      _product        = null;
      _scannedBarcode = null;
      _stockEdits.clear();
    });
  }

  // ─── Stok değişikliği callback (accordion'dan) ───────────────────────────

  void _onStockChanged(String unitType, double stockInBaseUnits) {
    _stockEdits[unitType] = stockInBaseUnits;
  }

  // ─── Kaydet ───────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_product == null || _selectedStockCount == null) return;

    // Tüm baz birim stoklarını topla
    final totalStock = _stockEdits.values.fold<double>(0, (s, v) => s + v);

    if (totalStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen en az bir birim için stok girin.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await StockService.addItem(
        _selectedStockCount!.id,
        _product!.productId,
        totalStock,
      );

      if (mounted) {
        // Özet bilgisi: her girdilen birim listele
        final summaryParts = <String>[];
        for (final g in _product!.barcodeGroups) {
          final entered = _stockEdits[g.unitType];
          if (entered == null || entered <= 0) continue;
          final qty = g.unitQuantity ?? 1.0;
          if (qty > 1) {
            final koliCount = (entered / qty).round();
            summaryParts.add(
                '$koliCount ${g.unitType} (${entered.toStringAsFixed(0)} adet)');
          } else {
            summaryParts.add('${entered.toStringAsFixed(0)} ${g.unitType}');
          }
        }
        final summary = summaryParts.join('  +  ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Stok kaydedildi: $summary\nToplam: ${totalStock.toStringAsFixed(0)} adet'),
          ),
        );
        _clearProduct();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kayıt sırasında hata oluştu.')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── Yeni sayım oluştur ────────────────────────────────────────────────────

  Future<void> _createStockCount() async {
    final branchId = context.read<HomeProvider>().activeBranchId;
    if (branchId == null) return;

    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Sayım Oluştur'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Sayım Adı',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              Navigator.pop(context);
              try {
                final count = await StockService.createStockCount(
                  nameController.text.trim(),
                  int.parse(branchId),
                );
                setState(() {
                  _activeCounts.add(count);
                  _selectedStockCount = count;
                });
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sayım oluşturulamadı.')),
                  );
                }
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final role    = context.watch<HomeProvider>().role;
    final isAdmin = role == 'admin' || role == 'superadmin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Gir'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _createStockCount,
              tooltip: 'Yeni Sayım Oluştur',
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
                  // ─── Sayım seçimi ──────────────────────────────────────
                  DropdownButtonFormField<StockCount>(
                    value: _selectedStockCount,
                    decoration: const InputDecoration(
                      labelText: 'Aktif Sayım Seç',
                      border: OutlineInputBorder(),
                    ),
                    items: _activeCounts
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStockCount = value;
                        _clearProduct();
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // ─── Barkod tarayıcı ───────────────────────────────────
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
                            if (barcode.isNotEmpty) {
                              _onBarcodeScanned(barcode);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, size: 32),
                        onPressed: () async {
                          final barcode =
                              await BarcodeScannerScreen.scan(context);
                          if (barcode != null) {
                            await _onBarcodeScanned(barcode);
                          }
                        },
                      ),
                    ],
                  ),

                  // ─── Ürün kartı + stok girişi ──────────────────────────
                  if (_product != null) ...[
                    const SizedBox(height: 16),
                    _ProductInfoCard(product: _product!),
                    const SizedBox(height: 12),

                    // Accordion: readonly fiyatlar + birim bazlı stok girişi
                    BarcodeGroupsAccordion(
                      barcodeGroups: _product!.barcodeGroups,
                      readonlyPrices: true,
                      onStockChanged: _onStockChanged,
                    ),
                    const SizedBox(height: 12),

                    // Toplam özet (dolu olanlar)
                    if (_stockEdits.isNotEmpty)
                      _StockSummaryCard(
                        product:    _product!,
                        stockEdits: _stockEdits,
                      ),

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Stoku Kaydet'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _clearProduct,
                      child: const Text('Temizle'),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ─── Sayımı tamamla ────────────────────────────────────
                  if (_selectedStockCount != null && isAdmin)
                    OutlinedButton(
                      onPressed: () async {
                        await StockService.completeStockCount(
                            _selectedStockCount!.id);
                        setState(() {
                          _activeCounts.remove(_selectedStockCount);
                          _selectedStockCount = null;
                          _clearProduct();
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Sayım tamamlandı.')),
                          );
                        }
                      },
                      child: const Text('Sayımı Tamamla'),
                    ),
                ],
              ),
            ),
    );
  }
}

// ─── Ürün bilgi kartı (salt okunur) ──────────────────────────────────────

class _ProductInfoCard extends StatelessWidget {
  final Product product;
  const _ProductInfoCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.productName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (product.marka != null) _Chip(product.marka!, Colors.blue),
                if (product.kategori != null)
                  _Chip(product.kategori!, Colors.green),
                _Chip('KDV %${product.kdvOrani}', Colors.grey),
                _Chip('#${product.productId}', Colors.blueGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Toplam stok özet kartı ────────────────────────────────────────────────

class _StockSummaryCard extends StatelessWidget {
  final Product product;
  final Map<String, double> stockEdits;

  const _StockSummaryCard({required this.product, required this.stockEdits});

  @override
  Widget build(BuildContext context) {
    final total =
        stockEdits.values.fold<double>(0, (s, v) => s + v);

    final rows = product.barcodeGroups
        .where((g) =>
            stockEdits.containsKey(g.unitType) &&
            (stockEdits[g.unitType] ?? 0) > 0)
        .toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Girilecek Stok',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          ...rows.map((g) {
            final baseUnits = stockEdits[g.unitType]!;
            final qty = g.unitQuantity ?? 1.0;
            final koliCount = qty > 1 ? (baseUnits / qty) : null;
            final satisFiyati = g.satisFiyati;

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text(
                    koliCount != null
                        ? '${koliCount.toStringAsFixed(0)} ${g.unitType} '
                            '× ${qty.toStringAsFixed(0)} = '
                            '${baseUnits.toStringAsFixed(0)} adet'
                        : '${baseUnits.toStringAsFixed(0)} adet',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (satisFiyati != null && satisFiyati > 0) ...[
                    const Spacer(),
                    Text(
                      '${(baseUnits * satisFiyati).toStringAsFixed(2)} ₺',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            );
          }),
          if (rows.length > 1) ...[
            const Divider(height: 12),
            Text(
              'Toplam: ${total.toStringAsFixed(0)} adet',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Chip ─────────────────────────────────────────────────────────────────

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

enum _StockNotFoundChoice { newProduct, addToExisting }
