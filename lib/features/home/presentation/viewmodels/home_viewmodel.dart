import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── State ────────────────────────────────────────────────────────────────────

sealed class HomeState {
  const HomeState();
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  const HomeLoaded({required this.data});
  final dynamic data;
}

class HomeError extends HomeState {
  const HomeError({required this.message});
  final String message;
}

// ── ViewModel ────────────────────────────────────────────────────────────────

class HomeViewModel extends Notifier<HomeState> {
  @override
  HomeState build() => const HomeInitial();

  Future<void> loadData() async {
    state = const HomeLoading();
    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      state = const HomeLoaded(data: 'Welcome to Riverflow!');
    } on Exception catch (e) {
      state = HomeError(message: e.toString());
    }
  }
}

final homeViewModelProvider =
    NotifierProvider<HomeViewModel, HomeState>(HomeViewModel.new);
