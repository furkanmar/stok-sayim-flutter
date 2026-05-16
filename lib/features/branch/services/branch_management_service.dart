import '../../../core/services/api_service.dart';
import '../../../core/utils/logger.dart';
import '../../home/models/branch.dart';

class BranchManagementService {
  static Future<Branch> createBranch(String name) async {
    try {
      logger.i('Creating branch: $name');
      final response = await ApiService.dio.post('/api/branches', data: {'name': name});
      logger.i('Branch created: $name');
      return Branch.fromJson(response.data);
    } catch (e) {
      logger.e('Failed to create branch: $e');
      rethrow;
    }
  }

  static Future<Branch> updateBranch(int id, String name) async {
    try {
      logger.i('Updating branch: $id');
      final response = await ApiService.dio.put('/api/branches/$id', data: {'name': name});
      logger.i('Branch updated: $name');
      return Branch.fromJson(response.data);
    } catch (e) {
      logger.e('Failed to update branch: $e');
      rethrow;
    }
  }

  static Future<void> deleteBranch(int id) async {
    try {
      logger.i('Deleting branch: $id');
      await ApiService.dio.delete('/api/branches/$id');
      logger.i('Branch deleted: $id');
    } catch (e) {
      logger.e('Failed to delete branch: $e');
      rethrow;
    }
  }
}