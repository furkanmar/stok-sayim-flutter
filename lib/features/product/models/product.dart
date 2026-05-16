/// Tek bir unit_type'a ait barkodlar + güncel fiyat
class BarcodeGroup {
  final String unitType;
  final double? unitQuantity;
  final List<String> barcodes;
  final double? alisFiyati;
  final double? satisFiyati;

  BarcodeGroup({
    required this.unitType,
    this.unitQuantity,
    required this.barcodes,
    this.alisFiyati,
    this.satisFiyati,
  });

  factory BarcodeGroup.fromJson(Map<String, dynamic> json) {
    return BarcodeGroup(
      unitType: json['unitType'] ?? 'ADT',
      unitQuantity: (json['unitQuantity'] as num?)?.toDouble(),
      barcodes: List<String>.from(json['barcodes'] ?? []),
      alisFiyati: (json['alisFiyati'] as num?)?.toDouble(),
      satisFiyati: (json['satisFiyati'] as num?)?.toDouble(),
    );
  }
}

/// Tam ürün verisi — barkod grupları ve fiyatlar dahil
class Product {
  final int productId;
  final String productName;
  final String unit;
  final String? content;
  final int kdvOrani;
  final String? kategori;
  final String? altKategori;
  final String? marka;
  final List<BarcodeGroup> barcodeGroups;

  Product({
    required this.productId,
    required this.productName,
    required this.unit,
    this.content,
    this.kdvOrani = 20,
    this.kategori,
    this.altKategori,
    this.marka,
    this.barcodeGroups = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productId: json['productId'] as int,
      productName: json['productName'] ?? '',
      unit: json['unit'] ?? '',
      content: json['content'],
      kdvOrani: json['kdvOrani'] ?? 20,
      kategori: json['kategori'],
      altKategori: json['altKategori'],
      marka: json['marka'],
      barcodeGroups: (json['barcodeGroups'] as List<dynamic>?)
              ?.map((e) => BarcodeGroup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Fiyat geçmişi tek kaydı
class ProductPriceEntry {
  final int id;
  final String unitType;
  final double alisFiyati;
  final double satisFiyati;
  final DateTime gecerlilikTarihi;

  ProductPriceEntry({
    required this.id,
    required this.unitType,
    required this.alisFiyati,
    required this.satisFiyati,
    required this.gecerlilikTarihi,
  });

  factory ProductPriceEntry.fromJson(Map<String, dynamic> json) {
    return ProductPriceEntry(
      id:                json['id'] as int,
      unitType:          json['unitType'] ?? 'ADT',
      alisFiyati:        (json['alisFiyati'] as num).toDouble(),
      satisFiyati:       (json['satisFiyati'] as num).toDouble(),
      gecerlilikTarihi:  DateTime.parse(json['gecerlilikTarihi']),
    );
  }
}

/// Arama sonuçları için sade ürün bilgisi
class SearchProduct {
  final int productId;
  final String productName;
  final String? marka;
  final String unit;

  SearchProduct({
    required this.productId,
    required this.productName,
    this.marka,
    required this.unit,
  });

  factory SearchProduct.fromJson(Map<String, dynamic> json) {
    return SearchProduct(
      productId: json['productId'] as int,
      productName: json['productName'] ?? '',
      marka: json['marka'],
      unit: json['unit'] ?? '',
    );
  }
}
