import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dio_client.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final FlutterSecureStorage storage;

  AuthInterceptor({required this.dio, required this.storage});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final accessToken = await storage.read(key: 'accessToken');
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // If unauthorized, attempt to refresh token
    if (err.response?.statusCode == 401 && err.requestOptions.path != '/auth/refresh' && err.requestOptions.path != '/auth/login') {
      final refreshToken = await storage.read(key: 'refreshToken');
      
      if (refreshToken != null) {
        try {
          // Attempt refresh
          final response = await Dio().post(
            '$baseUrl/auth/refresh',
            data: {'refreshToken': refreshToken},
          );

          if (response.statusCode == 200) {
            final newAccessToken = response.data['accessToken'];
            final newRefreshToken = response.data['refreshToken'];

            await storage.write(key: 'accessToken', value: newAccessToken);
            await storage.write(key: 'refreshToken', value: newRefreshToken);

            // Retry original request
            err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
            final retryResponse = await dio.fetch(err.requestOptions);
            return handler.resolve(retryResponse);
          }
        } catch (e) {
          // Refresh failed, clear tokens
          await storage.delete(key: 'accessToken');
          await storage.delete(key: 'refreshToken');
        }
      } else {
        // No refresh token available, force logout
        await storage.delete(key: 'accessToken');
      }
    }
    
    return handler.next(err);
  }
}
