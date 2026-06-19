import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_addis_app/features/report/presentation/viewmodels/report_viewmodel.dart';

class ReportView extends ConsumerStatefulWidget {
  const ReportView({super.key});

  @override
  ConsumerState<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends ConsumerState<ReportView> {
  String _selectedCategory = '';
  final TextEditingController _detailsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(reportViewModelProvider.notifier).loadCategories(),
    );
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submitReport() {
    ref.read(reportViewModelProvider.notifier).submitIssue(
          category: _selectedCategory,
          details: _detailsController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportViewModelProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report an Issue',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Choose a service category and tell us what needs attention in your area.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            switch (state) {
              ReportLoading() =>
                const Center(child: CircularProgressIndicator()),
              ReportError(:final message) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: scheme.error)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref
                          .read(reportViewModelProvider.notifier)
                          .loadCategories(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ReportSuccess(:final message) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: scheme.primary)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        _detailsController.clear();
                        setState(() {
                          _selectedCategory = '';
                        });
                        ref
                            .read(reportViewModelProvider.notifier)
                            .loadCategories();
                      },
                      child: const Text('Create another report'),
                    ),
                  ],
                ),
              ReportLoaded(:final categories) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: categories.map((category) {
                        final isSelected = category == _selectedCategory;
                        return ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          selectedColor: scheme.primary,
                          backgroundColor: scheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? scheme.onPrimary
                                : scheme.onSurface,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _detailsController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Describe the issue in your community',
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitReport,
                        child: const Text('Submit report'),
                      ),
                    ),
                  ],
                ),
              _ => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }
}
