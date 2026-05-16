import '../../../core/services/api_service.dart';
import '../../../core/utils/logger.dart';
import '../models/app_user.dart';

class UserService {
  static Future<List<AppUser>> getUsers(String companyId) async {
    try {
      logger.i('Fetching users');
      final response = await ApiService.dio.get('/api/users');
      final users = (response.data as List)
          .map((e) => AppUser.fromJson(e))
          .toList();
      logger.i('Users fetched: ${users.length}');
      return users;
    } catch (e) {
      logger.e('Failed to fetch users: $e');
      rethrow;
    }
  }

  static Future<void> saveUser(AppUser user) async {
    try {
      if (user.id == null) {
        logger.i('Creating user: ${user.username}');
        await ApiService.dio.post('/api/users', data: user.toJson());
        logger.i('User created: ${user.username}');
      } else {
        logger.i('Updating user: ${user.username}');
        await ApiService.dio.put('/api/users/${user.id}', data: user.toJson());
        logger.i('User updated: ${user.username}');
      }
    } catch (e) {
      logger.e('Failed to save user: $e');
      rethrow;
    }
  }

  static Future<void> deleteUser(String userId) async {
    try {
      logger.i('Deleting user: $userId');
      await ApiService.dio.delete('/api/users/$userId');
      logger.i('User deleted: $userId');
    } catch (e) {
      logger.e('Failed to delete user: $e');
      rethrow;
    }
  }
}