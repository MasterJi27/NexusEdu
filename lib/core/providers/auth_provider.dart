import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_edu/core/models/app_user.dart';
import 'package:nexus_edu/core/repositories/auth_repository.dart';
import 'package:nexus_edu/core/utils/result.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.uninitialized,
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, AppUser? user, bool? isLoading, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<void> checkAuthStatus() async {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(email, password);
    switch (result) {
      case Success<AppUser>():
        state = AuthState(status: AuthStatus.authenticated, user: result.data);
      case Failure<AppUser>():
        state = state.copyWith(isLoading: false, error: result.message);
    }
  }

  Future<void> signup(String name, String email, String password, {UserRole role = UserRole.student}) async {
    state = state.copyWith(isLoading: true, error: null);
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signup(name, email, password, role: role);
    switch (result) {
      case Success<AppUser>():
        state = AuthState(status: AuthStatus.authenticated, user: result.data);
      case Failure<AppUser>():
        state = state.copyWith(isLoading: false, error: result.message);
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signInWithGoogle();
    switch (result) {
      case Success<AppUser>():
        state = AuthState(status: AuthStatus.authenticated, user: result.data);
      case Failure<AppUser>():
        state = state.copyWith(isLoading: false, error: result.message);
    }
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
