abstract class ReportRepository {
  Future<List<String>> fetchReportCategories();
  Future<bool> submitIssue({required String category, required String details});
}
