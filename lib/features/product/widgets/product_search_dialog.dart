import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/utils/logger.dart';
import '../models/product.dart';
import '../services/product_service.dart';

/// Barkod bulunamadığında kullanıcının ürün adı ile arama yapıp
/// taradığı barkodu o ürüne ekleyebileceği dialog.
///
/// Barkod eklenirken unit_type ve gerekirse unitQuantity da seçilir.
class ProductSearchDialog extends StatefulWidget {
  final String missingBarcode;

  const ProductSearchDialog({super.key, required this.missingBarcode});

  static Future<SearchProduct?> show(BuildContext context,
      {required String missingBarcode}) {
    return showDialog<SearchProduct>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductSearchDialog(missingBarcode: missingBarcode),
    );
  }

  @override
  State<ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<ProductSearchDialog> {
  static const _unitTypes = ['ADT', 'KL', 'PAK', 'KG', 'GR', 'L', 'ML', 'BX'];
  // Birden fazla ADT barındıran tipler — miktar alanı gösterilir
  static const _multipackTypes = {'KL', 'PAK', 'BX'};

  List<String> _markas = [];
  bool _loadingMarkas  = true;
  String? _selectedMarka;

  final _searchController   = TextEditingController();
  final _quantityController = TextEditingController();
  List<SearchProduct> _results = [];
  bool _isSearching = false;
  Timer? _debounce;

  SearchProduct? _selectedProduct;
  String _selectedUnitType = 'ADT';
  bool _isSaving = false;

  bool get _needsQuantity => _multipackTypes.contains(_selectedUnitType);

  @override
  void initState() {
    super.initState();
    _loadMarkas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadMarkas() async {
    final markas = await ProductService.getMarkas();
    if (!mounted) return;
    setState(() {
      _markas = markas;
      _loadingMarkas = false;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String query) async {
    setState(() {
      _isSearching = true;
      _selectedProduct = null;
    });

    final results = await ProductService.searchProducts(query, marka: _selectedMarka);
    if (!mounted) return;

    setState(() {
      _results     = results;
      _isSearching = false;
    });
    logger.i('Search "$query": ${results.length} results');
  }

  void _onMarkaChanged(String? marka) {
    setState(() {
      _selectedMarka   = marka;
      _selectedProduct = null;
    });
    final q = _searchController.text.trim();
    if (q.length >= 2) _search(q);
  }

  Future<void> _confirm() async {
    if (_selectedProduct == null) return;
    setState(() => _isSaving = true);

    double? unitQuantity;
    if (_needsQuantity) {
      final v = double.tryParse(_quantityController.text.trim());
      if (v != null && v > 1) unitQuantity = v;
    }

    final ok = await ProductService.addBarcode(
      _selectedProduct!.productId,
      widget.missingBarcode,
      _selectedUnitType,
      unitQuantity: unitQuantity,
    );
    if (!mounted) return;

    if (!ok) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barkod eklenemedi. Zaten kayıtlı olabilir.')),
      );
      return;
    }

    Navigator.of(context).pop(_selectedProduct);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ürün Ara',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                'Barkod bulunamadı: ${widget.missingBarcode}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),

              // Arama kutusu
              TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Ürün adı ile ara...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _results = []);
                              },
                            )
                          : null,
                ),
              ),
              const SizedBox(height: 8),

              // Marka filtresi
              _loadingMarkas
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<String>(
                      value: _selectedMarka,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        hintText: 'Tüm markalar',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Tüm markalar',
                              style: TextStyle(color: Colors.grey)),
                        ),
                        ..._markas.map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: _onMarkaChanged,
                    ),
              const SizedBox(height: 8),

              // Sonuç listesi
              Expanded(child: _buildResultsList()),

              // Seçili ürün varsa: birim tipi + miktar + onay
              if (_selectedProduct != null) ...[
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 6),

                // Birim tipi satırı
                Row(
                  children: [
                    const Text('Birim tipi:', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnitType,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        items: _unitTypes
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _selectedUnitType = v!;
                          _quantityController.clear();
                        }),
                      ),
                    ),
                  ],
                ),

                // Miktar alanı (KL / PAK / BX için)
                if (_needsQuantity) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '1 ${_selectedUnitType} kaç adet içeriyor? (örn: 24)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                _buildFooter(),
              ] else ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('İptal'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_searchController.text.trim().length < 2) {
      return Center(
        child: Text(
          'Aramak istediğiniz ürünün adını yazın',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (!_isSearching && _results.isEmpty) {
      return Center(
        child: Text(
          'Sonuç bulunamadı',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p          = _results[i];
        final isSelected = _selectedProduct?.productId == p.productId;
        return ListTile(
          dense: true,
          selected: isSelected,
          selectedTileColor:
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          leading: isSelected
              ? Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary)
              : const Icon(Icons.inventory_2_outlined, color: Colors.grey),
          title: Text(p.productName, style: const TextStyle(fontSize: 13)),
          subtitle: Text(
            '${p.marka ?? '-'} · ${p.unit} · #${p.productId}',
            style: const TextStyle(fontSize: 11),
          ),
          onTap: () => setState(() => _selectedProduct = p),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(null),
            child: const Text('İptal'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _confirm,
            child: _isSaving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Barkodu Ekle ve Devam'),
          ),
        ),
      ],
    );
  }
}
