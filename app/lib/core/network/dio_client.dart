import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_interceptor.dart';

const String baseUrl = 'http://127.0.0.1:3000/api/v1';

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
