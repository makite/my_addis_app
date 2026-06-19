import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_addis_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:my_addis_app/features/profile/domain/repositories/profile_repository.dart';

sealed class ProfileState {
  const ProfileState();
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded({required this.profile, required this.preferences});

  final Map<String, String> profile;
  final List<String> preferences;
}

class ProfileError extends ProfileState {
  const ProfileError({required this.message});

  final String message;
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return const ProfileRepositoryImpl();
});

final profileViewModelProvider =
    NotifierProvider<ProfileViewModel, ProfileState>(ProfileViewModel.new);

class ProfileViewModel extends Notifier<ProfileState> {
  @override
  ProfileState build() => const ProfileInitial();

  Future<void> loadData() async {
    state = const ProfileLoading();
    try {
      final repository = ref.read(profileRepositoryProvider);
      final profile = await repository.fetchUserProfile();
      final preferences = await repository.fetchPreferences();
      state = ProfileLoaded(profile: profile, preferences: preferences);
    } on Exception catch (e) {
      state = ProfileError(message: e.toString());
    }
  }
}
