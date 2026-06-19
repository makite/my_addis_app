import 'dart:async';

import 'package:my_addis_app/features/map/domain/repositories/map_repository.dart';

class MapRepositoryImpl implements MapRepository {
  const MapRepositoryImpl();

  @override
  Future<List<String>> fetchNearbyServices() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return const [
      'Public transport stops',
      'Healthcare centers',
      'Waste collection points',
      'Community services',
    ];
  }

  @override
  Future<String> fetchRegionSummary() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return 'Explore live city services, routes, and local access points across Addis Ababa.';
  }
}
