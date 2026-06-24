import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_edu/core/models/app_user.dart';
import 'package:nexus_edu/core/repositories/auth_repository.dart';
import 'package:nexus_edu/core/utils/result.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final AppUser? user;

  AuthState({this.isLoading = false, this.isAuthenticated = false, this.error, this.user});

  AuthState copyWith({bool? isLoading, bool? isAuthenticated, String? error, AppUser? user}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error ?? this.error,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState();

  Future<void> checkLoginStatus() async {}

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    final repo = AuthRepository();
    final result = await repo.login(email, password);
    return switch (result) {
      Success<AppUser> s => _onSuccess(s.data),
      Failure<AppUser> f => _onError(f.message),
    };
  }

  Future<bool> signup(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    final repo = AuthRepository();
    final result = await repo.signup(name, email, password);
    return switch (result) {
      Success<AppUser> s => _onSuccess(s.data),
      Failure<AppUser> f => _onError(f.message),
    };
  }

  Future<void> logout() async {
    final repo = AuthRepository();
    await repo.logout();
    state = AuthState();
  }

  bool _onSuccess(AppUser user) {
    state = state.copyWith(isLoading: false, isAuthenticated: true, user: user);
    return true;
  }

  bool _onError(String message) {
    state = state.copyWith(isLoading: false, error: message);
    return false;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
