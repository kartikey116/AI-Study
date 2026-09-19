import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/dio_client.dart';
import '../domain/models/user_model.dart';

class AuthRepository {
  final DioClient _api = DioClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<UserModel?> register(String email, String password, String firstName, String lastName) async {
    final response = await _api.dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
    });
    await _saveTokens(response.data['accessToken'], response.data['refreshToken']);
    if (response.data['user'] != null) {
      return UserModel.fromJson(response.data['user']);
    }
    return null;
  }

  Future<UserModel?> login(String email, String password) async {
    final response = await _api.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await _saveTokens(response.data['accessToken'], response.data['refreshToken']);
    if (response.data['user'] != null) {
      return UserModel.fromJson(response.data['user']);
    }
    return null;
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: 'refreshToken');
    try {
      if (refreshToken != null) {
        await _api.dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } catch (e) {
      // Ignore network errors on logout
    }
    await _clearTokens();
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await _api.dio.get('/users/me');
      return UserModel.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<bool> hasValidToken() async {
    final token = await _storage.read(key: 'accessToken');
    return token != null;
  }

  Future<void> _saveTokens(String access, String refresh) async {
    await _storage.write(key: 'accessToken', value: access);
    await _storage.write(key: 'refreshToken', value: refresh);
  }

  Future<void> _clearTokens() async {
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'refreshToken');
  }
}
