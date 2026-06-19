abstract class MapRepository {
  Future<List<String>> fetchNearbyServices();
  Future<String> fetchRegionSummary();
}
