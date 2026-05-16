import '../../../core/services/api_service.dart';
import '../../../core/utils/logger.dart';
import '../models/report.dart';

class ReportService {
  static Future<BranchReport> getBranchReport(String branchId) async {
    try {
      logger.i('Fetching report for branch: $branchId');
      final response = await ApiService.dio.get('/api/reports/branch/$branchId');
      final report = BranchReport.fromJson(response.data);
      logger.i('Report fetched for branch $branchId');
      return report;
    } catch (e) {
      logger.e('Failed to fetch report for branch $branchId: $e');
      rethrow;
    }
  }

  /// Birden fazla şubenin raporunu paralel olarak çeker.
  /// Hata veren şubeler sonuç listesine dahil edilmez.
  static Future<List<BranchReport>> getMultiBranchReports(
      List<String> branchIds) async {
    final results = await Future.wait(
      branchIds.map((id) async {
        try {
          return await getBranchReport(id);
        } catch (e) {
          logger.w('Skipping branch $id due to error: $e');
          return null;
        }
      }),
    );
    return results.whereType<BranchReport>().toList();
  }
}