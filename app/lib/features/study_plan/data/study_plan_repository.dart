import '../../../../core/network/dio_client.dart';

class StudyPlanRepository {
  final DioClient _dioClient;

  StudyPlanRepository(this._dioClient);

  Future<Map<String, dynamic>?> getActivePlan() async {
    final response = await _dioClient.dio.get('/study/plan');
    if (response.data == null) return null;
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generatePlan({
    required DateTime targetDate,
    required List<String> subjects,
    required int hoursPerDay,
  }) async {
    final response = await _dioClient.dio.post('/study/plan', data: {
      'targetDate': targetDate.toIso8601String(),
      'subjects': subjects,
      'hoursPerDay': hoursPerDay,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> toggleTask(String taskId) async {
    final response = await _dioClient.dio.patch('/study/task/$taskId/toggle');
    return response.data as Map<String, dynamic>;
  }

  Future<void> deletePlan(String planId) async {
    await _dioClient.dio.delete('/study/plan/$planId');
  }
}
