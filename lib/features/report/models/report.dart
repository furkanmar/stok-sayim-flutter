class SubCategoryReport {
  final String subCategory;
  final double totalAlis;
  final double totalSatis;

  SubCategoryReport({
    required this.subCategory,
    required this.totalAlis,
    required this.totalSatis,
  });

  factory SubCategoryReport.fromJson(Map<String, dynamic> json) {
    return SubCategoryReport(
      subCategory: json['subCategory'] ?? 'Kategorisiz',
      totalAlis: (json['totalAlis'] as num).toDouble(),
      totalSatis: (json['totalSatis'] as num).toDouble(),
    );
  }
}

class CategoryReport {
  final String category;
  final double totalAlis;
  final double totalSatis;
  final List<SubCategoryReport> subCategories;

  CategoryReport({
    required this.category,
    required this.totalAlis,
    required this.totalSatis,
    required this.subCategories,
  });

  factory CategoryReport.fromJson(Map<String, dynamic> json) {
    return CategoryReport(
      category: json['category'] ?? 'Kategorisiz',
      totalAlis: (json['totalAlis'] as num).toDouble(),
      totalSatis: (json['totalSatis'] as num).toDouble(),
      subCategories: (json['subCategories'] as List)
          .map((e) => SubCategoryReport.fromJson(e))
          .toList(),
    );
  }
}

class StockCountReport {
  final int id;
  final String name;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<CategoryReport> categories;
  final double grandTotalAlis;
  final double grandTotalSatis;

  StockCountReport({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.categories,
    required this.grandTotalAlis,
    required this.grandTotalSatis,
  });

  factory StockCountReport.fromJson(Map<String, dynamic> json) {
    return StockCountReport(
      id: json['id'],
      name: json['name'],
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      categories: (json['categories'] as List)
          .map((e) => CategoryReport.fromJson(e))
          .toList(),
      grandTotalAlis: (json['grandTotalAlis'] as num).toDouble(),
      grandTotalSatis: (json['grandTotalSatis'] as num).toDouble(),
    );
  }
}

class BranchReport {
  final int branchId;
  final String branchName;
  final List<StockCountReport> stockCounts;

  BranchReport({
    required this.branchId,
    required this.branchName,
    required this.stockCounts,
  });

  factory BranchReport.fromJson(Map<String, dynamic> json) {
    return BranchReport(
      branchId: json['branchId'],
      branchName: json['branchName'],
      stockCounts: (json['stockCounts'] as List)
          .map((e) => StockCountReport.fromJson(e))
          .toList(),
    );
  }
}