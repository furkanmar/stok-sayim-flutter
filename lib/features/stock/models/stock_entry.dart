class StockEntry {
  final String barcode;
  final int stockCountId;
  final double stock;

  StockEntry({
    required this.barcode,
    required this.stockCountId,
    required this.stock,
  });

  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'stockCountId': stockCountId,
      'stock': stock,
    };
  }
} 