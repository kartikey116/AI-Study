import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_model.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

enum AuthState { initial, unauthenticated, authenticated, loading, error }

class AuthStateData {
  final AuthState status;
  final UserModel? user;
  final String? errorMessage;

  AuthStateData({required this.status, this.user, this.errorMessage});
}

class AuthNotifier extends StateNotifier<AuthStateData> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthStateData(status: AuthState.initial)) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    state = AuthStateData(status: AuthState.loading);
    if (await _repository.hasValidToken()) {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        state = AuthStateData(status: AuthState.authenticated, user: user);
        return;
      }
    }
    state = AuthStateData(status: AuthState.unauthenticated);
  }

  Future<void> login(String email, String password) async {
    state = AuthStateData(status: AuthState.loading);
    try {
      final userResponse = await _repository.login(email.trim(), password);
      final user = userResponse ?? await _repository.getCurrentUser();
      state = AuthStateData(status: AuthState.authenticated, user: user);
    } on DioException catch (e) {
      String msg = 'Invalid email or password';
      if (e.response?.data is Map && e.response?.data['error'] != null) {
        msg = e.response?.data['error'].toString() ?? msg;
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.connectionError ||
                 e.type == DioExceptionType.receiveTimeout) {
        msg = 'Cannot connect to backend server. Make sure phone is connected via USB or Wi-Fi.';
      }
      state = AuthStateData(status: AuthState.error, errorMessage: msg);
    } catch (e) {
      state = AuthStateData(status: AuthState.error, errorMessage: 'An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<void> register(String email, String password, String firstName, String lastName) async {
    state = AuthStateData(status: AuthState.loading);
    try {
      final userResponse = await _repository.register(email.trim(), password, firstName.trim(), lastName.trim());
      final user = userResponse ?? await _repository.getCurrentUser();
      state = AuthStateData(status: AuthState.authenticated, user: user);
    } on DioException catch (e) {
      String msg = 'Registration failed';
      if (e.response?.data is Map && e.response?.data['error'] != null) {
        msg = e.response?.data['error'].toString() ?? msg;
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.connectionError) {
        msg = 'Cannot connect to backend server.';
      }
      state = AuthStateData(status: AuthState.error, errorMessage: msg);
    } catch (e) {
      state = AuthStateData(status: AuthState.error, errorMessage: 'An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    state = AuthStateData(status: AuthState.loading);
    await _repository.logout();
    state = AuthStateData(status: AuthState.unauthenticated);
  }

  void clearError() {
    if (state.status == AuthState.error) {
      state = AuthStateData(status: AuthState.unauthenticated);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthStateData>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
