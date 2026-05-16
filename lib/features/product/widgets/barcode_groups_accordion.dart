import 'package:flutter/material.dart';
import '../models/product.dart';

/// Bir ürünün tüm barkod gruplarını unit_type'a göre ayrıştırıp
/// açılır/kapanır bir akordeon olarak gösterir.
///
/// Üç mod:
///  - [showPriceFields]=true  → alış/satış fiyat alanları düzenlenebilir
///  - [readonlyPrices]=true   → fiyatlar salt okunur + stok giriş alanı
///  - hiçbiri                 → sadece barkod listesi
class BarcodeGroupsAccordion extends StatefulWidget {
  final List<BarcodeGroup> barcodeGroups;

  /// Fiyat alanları düzenlenebilir (ürün ekle/düzenle ekranı)
  final bool showPriceFields;

  /// Fiyatlar salt okunur, stok girişi aktif (stok giriş ekranı)
  final bool readonlyPrices;

  /// Fiyat değişikliği geri bildirimi (showPriceFields modunda)
  final void Function(String unitType, double? alis, double? satis)?
      onPriceChanged;

  /// Stok değişikliği geri bildirimi (readonlyPrices modunda)
  /// — değer daima "baz birim" (ADT) cinsindendir
  final void Function(String unitType, double stockInBaseUnits)? onStockChanged;

  /// Barkod silme isteği (showPriceFields modunda görünür).
  /// Callback çağrıldığında üst widget silme işlemini yapar ve ürünü yeniler.
  final void Function(String barcode, String unitType)? onDeleteBarcode;

  const BarcodeGroupsAccordion({
    super.key,
    required this.barcodeGroups,
    this.showPriceFields = false,
    this.readonlyPrices = false,
    this.onPriceChanged,
    this.onStockChanged,
    this.onDeleteBarcode,
  });

  @override
  State<BarcodeGroupsAccordion> createState() => _BarcodeGroupsAccordionState();
}

class _BarcodeGroupsAccordionState extends State<BarcodeGroupsAccordion> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    // Stok veya fiyat modunda ya da tek grup varsa baştan açık
    _expanded = widget.showPriceFields ||
        widget.readonlyPrices ||
        widget.barcodeGroups.length == 1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.barcodeGroups.isEmpty) return const SizedBox.shrink();

    final totalBarcodes =
        widget.barcodeGroups.fold<int>(0, (s, g) => s + g.barcodes.length);
    final groupCount = widget.barcodeGroups.length;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // ─── Başlık (tıklanabilir) ─────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    widget.readonlyPrices
                        ? Icons.inventory_2_outlined
                        : Icons.qr_code,
                    size: 20,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$groupCount birim tipi  ·  $totalBarcodes barkod',
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // ─── İçerik ────────────────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1),
            ...widget.barcodeGroups.map(
              (group) => _BarcodeGroupTile(
                group: group,
                showPriceFields: widget.showPriceFields,
                readonlyPrices: widget.readonlyPrices,
                onPriceChanged: widget.onPriceChanged,
                onStockChanged: widget.onStockChanged,
                onDeleteBarcode: widget.onDeleteBarcode,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _BarcodeGroupTile extends StatefulWidget {
  final BarcodeGroup group;
  final bool showPriceFields;
  final bool readonlyPrices;
  final void Function(String unitType, double? alis, double? satis)?
      onPriceChanged;
  final void Function(String unitType, double stockInBaseUnits)? onStockChanged;
  final void Function(String barcode, String unitType)? onDeleteBarcode;

  const _BarcodeGroupTile({
    required this.group,
    required this.showPriceFields,
    required this.readonlyPrices,
    this.onPriceChanged,
    this.onStockChanged,
    this.onDeleteBarcode,
  });

  @override
  State<_BarcodeGroupTile> createState() => _BarcodeGroupTileState();
}

class _BarcodeGroupTileState extends State<_BarcodeGroupTile> {
  late final TextEditingController _alisCtrl;
  late final TextEditingController _satisCtrl;
  late final TextEditingController _stockCtrl;

  /// Kullanıcının girdiği paket/koli adedi (qty > 1 ise kullanılır)
  double _enteredCount = 0;

  @override
  void initState() {
    super.initState();
    _alisCtrl = TextEditingController(
        text: widget.group.alisFiyati?.toStringAsFixed(2) ?? '');
    _satisCtrl = TextEditingController(
        text: widget.group.satisFiyati?.toStringAsFixed(2) ?? '');
    _stockCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _alisCtrl.dispose();
    _satisCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  void _notifyPriceChange() {
    widget.onPriceChanged?.call(
      widget.group.unitType,
      double.tryParse(_alisCtrl.text.trim()),
      double.tryParse(_satisCtrl.text.trim()),
    );
  }

  void _notifyStockChange(String raw) {
    final entered = double.tryParse(raw.trim()) ?? 0;
    _enteredCount = entered;
    final qty = widget.group.unitQuantity ?? 1.0;
    final baseUnits = entered * qty;
    widget.onStockChanged?.call(widget.group.unitType, baseUnits);
    setState(() {}); // önizleme güncelle
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final qty = group.unitQuantity;
    final hasQty = qty != null && qty > 1;

    final qtyText = hasQty
        ? '  ·  ${qty!.toStringAsFixed(0)} adet/birim'
        : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Birim tipi + miktar ─────────────────────────────────────
          Row(
            children: [
              _UnitBadge(group.unitType),
              const SizedBox(width: 6),
              if (qtyText.isNotEmpty)
                Text(
                  qtyText,
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // ── Barkodlar ───────────────────────────────────────────────
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: group.barcodes.map((bc) {
              if (widget.showPriceFields && widget.onDeleteBarcode != null) {
                // Düzenleme modunda: çöp kutusu ikonu olan chip
                return Chip(
                  label: Text(
                    bc,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade800,
                      fontFamily: 'monospace',
                    ),
                  ),
                  deleteIcon: const Icon(Icons.delete_outline, size: 16),
                  deleteIconColor: Colors.red.shade400,
                  onDeleted: () => widget.onDeleteBarcode!(bc, group.unitType),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                );
              }
              // Salt okunur mod: sadece metin
              return Text(
                bc,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontFamily: 'monospace',
                ),
              );
            }).toList(),
          ),

          // ── DÜZENLENEBİLİR fiyat alanları ──────────────────────────
          if (widget.showPriceFields) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _alisCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Alış ₺',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _notifyPriceChange(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _satisCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Satış ₺',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _notifyPriceChange(),
                  ),
                ),
              ],
            ),
          ],

          // ── SALT OKUNUR fiyat + STOK girişi ────────────────────────
          if (widget.readonlyPrices) ...[
            const SizedBox(height: 8),

            // Fiyat satırı (salt okunur)
            Row(
              children: [
                const Icon(Icons.sell_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                _PriceLabel('Alış', group.alisFiyati),
                const SizedBox(width: 12),
                const Icon(Icons.shopping_cart_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                _PriceLabel('Satış', group.satisFiyati),
              ],
            ),
            const SizedBox(height: 8),

            // Stok giriş alanı
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _stockCtrl,
                    decoration: InputDecoration(
                      labelText: hasQty
                          ? '${group.unitType} adedi'
                          : 'Stok (adet)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      suffixText: hasQty ? group.unitType : 'adet',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: _notifyStockChange,
                  ),
                ),
                if (hasQty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: Colors.amber.shade200),
                      ),
                      child: Text(
                        _enteredCount > 0
                            ? '${_enteredCount.toStringAsFixed(0)} × ${qty!.toStringAsFixed(0)} = '
                                '${(_enteredCount * qty).toStringAsFixed(0)} adet'
                            : '× ${qty!.toStringAsFixed(0)} adet/birim',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade800,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],

          const Divider(height: 16),
        ],
      ),
    );
  }
}

// ─── Yardımcı widget'lar ───────────────────────────────────────────────────

class _UnitBadge extends StatelessWidget {
  final String unitType;
  const _UnitBadge(this.unitType);

  @override
  Widget build(BuildContext context) {
    final color = _unitColor(unitType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        unitType,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _unitColor(String unitType) {
    switch (unitType.toUpperCase()) {
      case 'ADT':
        return Colors.blue;
      case 'KL':
        return Colors.orange;
      case 'PAK':
        return Colors.purple;
      case 'KG':
        return Colors.green;
      case 'GR':
        return Colors.teal;
      case 'L':
        return Colors.indigo;
      case 'ML':
        return Colors.cyan;
      default:
        return Colors.blueGrey;
    }
  }
}

class _PriceLabel extends StatelessWidget {
  final String label;
  final double? value;
  const _PriceLabel(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      value != null ? '$label: ${value!.toStringAsFixed(2)} ₺' : '$label: —',
      style: TextStyle(
        fontSize: 12,
        color: value != null ? Colors.black87 : Colors.grey,
        fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
      ),
    );
  }
}
