import '../../../core/network/api_service.dart';

class LeaveTypeApiService {
  final ApiService api;

  LeaveTypeApiService(this.api);

  Future<List<dynamic>> fetchLeaveTypes() async {
    final response = await api.get('/leave-types');

    return response['data'];
  }
}
