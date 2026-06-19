import 'dart:async';

import 'package:my_addis_app/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl();

  @override
  Future<Map<String, String>> fetchUserProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return {
      'name': 'Alemu Bekele',
      'email': 'alemu.bekele@example.com',
      'role': 'Community resident',
      'city': 'Addis Ababa',
    };
  }

  @override
  Future<List<String>> fetchPreferences() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return const [
      'Notifications',
      'Language: Amharic',
      'Public transport alerts',
      'City updates',
    ];
  }
}
