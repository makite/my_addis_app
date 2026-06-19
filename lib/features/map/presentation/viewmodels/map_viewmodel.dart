import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_addis_app/features/map/data/repositories/map_repository_impl.dart';
import 'package:my_addis_app/features/map/domain/repositories/map_repository.dart';

sealed class MapState {
  const MapState();
}

class MapInitial extends MapState {
  const MapInitial();
}

class MapLoading extends MapState {
  const MapLoading();
}

class MapLoaded extends MapState {
  const MapLoaded({required this.summary, required this.nearbyServices});

  final String summary;
  final List<String> nearbyServices;
}

class MapError extends MapState {
  const MapError({required this.message});

  final String message;
}

final mapRepositoryProvider = Provider<MapRepository>((ref) {
  return const MapRepositoryImpl();
});

final mapViewModelProvider =
    NotifierProvider<MapViewModel, MapState>(MapViewModel.new);

class MapViewModel extends Notifier<MapState> {
  @override
  MapState build() => const MapInitial();

  Future<void> loadData() async {
    state = const MapLoading();
    try {
      final repository = ref.read(mapRepositoryProvider);
      final summary = await repository.fetchRegionSummary();
      final nearbyServices = await repository.fetchNearbyServices();
      state = MapLoaded(summary: summary, nearbyServices: nearbyServices);
    } on Exception catch (e) {
      state = MapError(message: e.toString());
    }
  }
}
