import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';

class StorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    logger.i('StorageService initialized');
  }

  static Future<void> setToken(String token) async {
    await _prefs.setString(AppConstants.tokenKey, token);
    logger.d('Token saved');
  }

  static String? getToken() {
    return _prefs.getString(AppConstants.tokenKey);
  }

  static Future<void> setBaseUrl(String url) async {
    await _prefs.setString(AppConstants.baseUrlKey, url);
    logger.d('Base URL saved: $url');
  }

  static String getBaseUrl() {
    return _prefs.getString(AppConstants.baseUrlKey) ?? AppConstants.defaultBaseUrl;
  }

  static Future<void> setActiveBranch(String branch) async {
    await _prefs.setString(AppConstants.branchKey, branch);
    logger.d('Active branch saved: $branch');
  }

  static String? getActiveBranch() {
    return _prefs.getString(AppConstants.branchKey);
  }

  static Future<void> clear() async {
    await _prefs.clear();
    logger.i('Storage cleared');
  }
  static Future<void> setRole(String role) async {
    await _prefs.setString('user_role', role);
    logger.d('Role saved: $role');
  }

  static String getRole() {
    return _prefs.getString('user_role') ?? '';
  }

  static Future<void> setUsername(String username) async {
    await _prefs.setString('username', username);
    logger.d('Username saved: $username');
  }

  static String getUsername() {
    return _prefs.getString('username') ?? '';
  }
  static Future<void> setCompanyId(String companyId) async {
    await _prefs.setString('company_id', companyId);
    logger.d('CompanyId saved: $companyId');
  }

  static String getCompanyId() {
    return _prefs.getString('company_id') ?? '';
  }
}