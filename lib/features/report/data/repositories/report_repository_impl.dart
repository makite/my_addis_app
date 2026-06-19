import 'dart:async';

import 'package:my_addis_app/features/report/domain/repositories/report_repository.dart';

class ReportRepositoryImpl implements ReportRepository {
  const ReportRepositoryImpl();

  @override
  Future<List<String>> fetchReportCategories() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return const [
      'Road maintenance',
      'Public lighting',
      'Sanitation',
      'Noise complaint',
    ];
  }

  @override
  Future<bool> submitIssue(
      {required String category, required String details}) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return details.isNotEmpty && category.isNotEmpty;
  }
}
