class StockCount {
  final int id;
  final String name;
  final int branchId;
  final String status;
  final DateTime createdAt;

  StockCount({
    required this.id,
    required this.name,
    required this.branchId,
    required this.status,
    required this.createdAt,
  });

  factory StockCount.fromJson(Map<String, dynamic> json) {
    return StockCount(
      id: json['id'],
      name: json['name'],
      branchId: json['branchId'],
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}