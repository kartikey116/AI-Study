import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(DioClient());
});

final dashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return repository.getDashboardSummary();
});
