import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_addis_app/features/map/presentation/viewmodels/map_viewmodel.dart';

class MapView extends ConsumerStatefulWidget {
  const MapView({super.key});

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  // Initialization handled globally by appInitializerProvider

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapViewModelProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return switch (state) {
      MapLoading() => const Center(child: CircularProgressIndicator()),
      MapError(:final message) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: scheme.error),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(mapViewModelProvider.notifier).loadData(),
                  child: const Text('Refresh map'),
                ),
              ],
            ),
          ),
        ),
      MapLoaded(:final summary, :final nearbyServices) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'City Map',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.map_outlined,
                      size: 96,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Nearby service hubs',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ...nearbyServices.map(
                  (service) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      tileColor: scheme.surfaceContainerHighest,
                      leading: Icon(Icons.location_on, color: scheme.primary),
                      title: Text(service, style: theme.textTheme.bodyLarge),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
