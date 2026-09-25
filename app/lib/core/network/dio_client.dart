import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_interceptor.dart';

// Using Localtunnel to bypass Windows Firewall
const String baseUrl = 'https://able-eleven-dirt-ask.trycloudflare.com/api/v1';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  late final Dio dio;
  final storage = const FlutterSecureStorage();

  factory DioClient() {
    return _instance;
  }

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Bypass-Tunnel-Reminder': 'true', // Bypasses localtunnel warning page
        },
      ),
    );

    dio.interceptors.add(AuthInterceptor(dio: dio, storage: storage));
  }
}
