import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_interceptor.dart';

// Override per run: flutter run --dart-define=API_URL=http://<host>:3000/api/v1
// 127.0.0.1  → iOS Simulator, or Android phone over USB after `adb reverse tcp:3000 tcp:3000`
// 10.0.2.2   → Android Emulator only
// 192.168.x.x → Physical device on Wi-Fi (laptop's IP; fails if the router isolates clients)
const String baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://127.0.0.1:3000/api/v1',
);

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
