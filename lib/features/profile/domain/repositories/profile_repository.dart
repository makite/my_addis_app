abstract class ProfileRepository {
  Future<Map<String, String>> fetchUserProfile();
  Future<List<String>> fetchPreferences();
}
