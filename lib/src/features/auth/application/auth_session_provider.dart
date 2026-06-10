import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

final authSessionProvider =
    StateNotifierProvider<
      AuthSessionController,
      AsyncValue<AuthenticatedUser?>
    >((ref) {
      return AuthSessionController(ref.watch(authRepositoryProvider));
    });

class AuthSessionController
    extends StateNotifier<AsyncValue<AuthenticatedUser?>> {
  AuthSessionController(this._authRepository) : super(const AsyncLoading()) {
    _authStateSubscription = _authRepository.authStateChanges().listen(
      _syncSession,
      onError: (Object error, StackTrace stackTrace) {
        state = AsyncError(error, stackTrace);
      },
    );
  }

  final AuthRepository _authRepository;
  StreamSubscription<User?>? _authStateSubscription;

  Future<void> signInAsUser({required String email, required String password}) {
    return _signIn(
      email: email,
      password: password,
      expectedRole: UserRole.user,
    );
  }

  Future<void> signInAsAdmin({
    required String email,
    required String password,
  }) {
    return _signIn(
      email: email,
      password: password,
      expectedRole: UserRole.admin,
    );
  }

  Future<void> signUp({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _authRepository.signUp(
        fullName: fullName,
        username: username,
        email: email,
        password: password,
      ),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    await _authRepository.signOut();
    state = const AsyncData(null);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _authRepository.sendPasswordResetEmail(email);
  }

  Future<void> updatePhoneNumber(String phoneNumber) async {
    final session = state.valueOrNull;
    if (session == null) {
      return;
    }

    await _authRepository.updatePhoneNumber(
      uid: session.uid,
      phoneNumber: phoneNumber,
    );
    await _syncSession(null);
  }

  void continueAsGuest() {
    state = AsyncData(AuthenticatedUser.guest());
  }

  Future<void> _signIn({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _authRepository.signIn(
        email: email,
        password: password,
        expectedRole: expectedRole,
      ),
    );
  }

  Future<void> _syncSession(User? _) async {
    if (state.valueOrNull?.isGuest ?? false) {
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(_authRepository.currentSession);
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
