import 'package:dio/dio.dart';

import 'dashboard_academia.dart';

class DashboardApi {
  DashboardApi(this._dio);

  final Dio _dio;

  Future<DashboardAcademia> get() async {
    final response = await _dio.get<Map<String, dynamic>>('/dashboard');
    return DashboardAcademia.fromJson(response.data!);
  }
}
