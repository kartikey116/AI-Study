import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_interceptor.dart';

// 127.0.0.1  → iOS Simulator only
// 10.0.2.2   → Android Emulator only
// 192.168.x.x → Physical device (must match your laptop's Wi-Fi IP)
const String baseUrl = 'http://192.168.1.36:3000/api/v1';

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
      ),
    );

    dio.interceptors.add(AuthInterceptor(dio: dio, storage: storage));
  }
}
