import '../../../core/services/api_service.dart';
import '../../../core/utils/logger.dart';
import '../models/branch.dart';

class BranchService {
  static Future<List<Branch>> getBranches() async {
    try {
      logger.i('Fetching branches');
      final response = await ApiService.dio.get('/api/branches');
      final branches = (response.data as List)
          .map((e) => Branch.fromJson(e))
          .toList();
      logger.i('Branches fetched: ${branches.length}');
      return branches;
    } catch (e) {
      logger.e('Failed to fetch branches: $e');
      return [];
    }
  }
}