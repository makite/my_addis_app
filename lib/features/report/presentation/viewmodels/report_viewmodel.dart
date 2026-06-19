import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_addis_app/features/report/data/repositories/report_repository_impl.dart';
import 'package:my_addis_app/features/report/domain/repositories/report_repository.dart';

sealed class ReportState {
  const ReportState();
}

class ReportInitial extends ReportState {
  const ReportInitial();
}

class ReportLoading extends ReportState {
  const ReportLoading();
}

class ReportLoaded extends ReportState {
  const ReportLoaded({required this.categories});

  final List<String> categories;
}

class ReportSuccess extends ReportState {
  const ReportSuccess({required this.message});

  final String message;
}

class ReportError extends ReportState {
  const ReportError({required this.message});

  final String message;
}

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return const ReportRepositoryImpl();
});

final reportViewModelProvider =
    NotifierProvider<ReportViewModel, ReportState>(ReportViewModel.new);

class ReportViewModel extends Notifier<ReportState> {
  @override
  ReportState build() => const ReportInitial();

  Future<void> loadCategories() async {
    state = const ReportLoading();
    try {
      final repository = ref.read(reportRepositoryProvider);
      final categories = await repository.fetchReportCategories();
      state = ReportLoaded(categories: categories);
    } on Exception catch (e) {
      state = ReportError(message: e.toString());
    }
  }

  Future<void> submitIssue(
      {required String category, required String details}) async {
    state = const ReportLoading();
    try {
      final repository = ref.read(reportRepositoryProvider);
      final success =
          await repository.submitIssue(category: category, details: details);
      state = success
          ? const ReportSuccess(
              message: 'Your issue was submitted successfully.')
          : const ReportError(
              message: 'Please select a category and add details.');
    } on Exception catch (e) {
      state = ReportError(message: e.toString());
    }
  }
}
