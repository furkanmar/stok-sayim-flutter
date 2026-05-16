import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/logger.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';

class AuthService {
  static Future<LoginResponse> login(LoginRequest request) async {
    try {
      logger.i('Login attempt: ${request.username}');

      final response = await ApiService.dio.post(
        '/api/auth/login',
        data: request.toJson(),
      );

      final loginResponse = LoginResponse.fromJson(response.data);
      await StorageService.setToken(loginResponse.token);
      logger.i('Login successful: ${request.username} — role: ${loginResponse.role}');
      return loginResponse;
    } catch (e) {
      logger.e('Login failed: $e');
      rethrow;
    }
  }

  static Future<void> logout() async {
    final baseUrl = StorageService.getBaseUrl();
    await StorageService.clear();
    await StorageService.setBaseUrl(baseUrl);
    logger.i('User logged out');
  }
}