import '../../../core/services/api_service.dart';
import '../../../core/utils/logger.dart';
import '../models/category.dart';

class CategoryService {
  static Future<List<Category>> getCategories() async {
    try {
      logger.i('Fetching categories');
      final response = await ApiService.dio.get('/api/categories');
      final categories = (response.data as List)
          .map((e) => Category.fromJson(e))
          .toList();
      logger.i('Categories fetched: ${categories.length}');
      return categories;
    } catch (e) {
      logger.e('Failed to fetch categories: $e');
      return [];
    }
  }
}