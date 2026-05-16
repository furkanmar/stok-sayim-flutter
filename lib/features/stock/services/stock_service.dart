import '../../../core/services/api_service.dart';
import '../../../core/utils/logger.dart';
import '../../product/services/product_service.dart';
import '../../product/models/product.dart';
import '../models/stock_count.dart';

class StockService {
  static Future<List<StockCount>> getActiveCounts(int branchId) async {
    try {
      logger.i('Fetching active stock counts for branch: $branchId');
      final response = await ApiService.dio.get('/api/stock/active/$branchId');
      final counts = (response.data as List)
          .map((e) => StockCount.fromJson(e))
          .toList();
      logger.i('Active counts fetched: ${counts.length}');
      return counts;
    } catch (e) {
      logger.e('Failed to fetch active counts: $e');
      return [];
    }
  }

  static Future<StockCount> createStockCount(String name, int branchId) async {
    try {
      logger.i('Creating stock count: $name');
      final response = await ApiService.dio.post('/api/stock/create', data: {
        'name': name,
        'branchId': branchId,
      });
      logger.i('Stock count created');
      return StockCount.fromJson(response.data);
    } catch (e) {
      logger.e('Failed to create stock count: $e');
      rethrow;
    }
  }

  static Future<void> addItem(int stockCountId, int productId, double stock) async {
    try {
      logger.i('Adding item to stock count: $stockCountId — productId: $productId, stock: $stock');
      await ApiService.dio.post('/api/stock/add-item', data: {
        'stockCountId': stockCountId,
        'productId': productId,
        'stock': stock,
      });
      logger.i('Item added successfully');
    } catch (e) {
      logger.e('Failed to add item: $e');
      rethrow;
    }
  }

  static Future<void> completeStockCount(int stockCountId) async {
    try {
      logger.i('Completing stock count: $stockCountId');
      await ApiService.dio.post('/api/stock/complete/$stockCountId');
      logger.i('Stock count completed');
    } catch (e) {
      logger.e('Failed to complete stock count: $e');
      rethrow;
    }
  }
}