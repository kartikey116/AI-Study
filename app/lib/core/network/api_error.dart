import 'package:dio/dio.dart';

/// Human-readable message for a failed API call: the server's `{ error }`
/// text when present, otherwise a short description instead of the raw
/// DioException dump.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The server took too long to respond. Please try again.',
      DioExceptionType.connectionError => "Can't reach the server. Check your connection.",
      _ => 'Something went wrong (${error.response?.statusCode ?? 'network error'}).',
    };
  }
  return error.toString().replaceFirst('Exception: ', '');
}
