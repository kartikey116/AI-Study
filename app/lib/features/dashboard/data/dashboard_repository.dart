import '../../../../core/network/dio_client.dart';

class DashboardRepository {
  final DioClient _dioClient;

  DashboardRepository(this._dioClient);

  Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      final response = await _dioClient.dio.get('/study/dashboard');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load dashboard summary: $e');
    }
  }
}
