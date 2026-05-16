import 'package:dio/dio.dart';
import '../utils/logger.dart';
import 'storage_service.dart';

class ApiService {
  static late Dio _dio;

  static void init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: StorageService.getBaseUrl(),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = StorageService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          logger.i('REQUEST: ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          logger.i('RESPONSE: ${response.statusCode} ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (error, handler) {
          logger.e('ERROR: ${error.response?.statusCode} ${error.requestOptions.path} — ${error.message}');
          return handler.next(error);
        },
      ),
    );

    logger.i('ApiService initialized');
  }

  static void updateBaseUrl(String newUrl) {
    _dio.options.baseUrl = newUrl;
    logger.i('Base URL updated: $newUrl');
  }

  static Dio get dio => _dio;
}