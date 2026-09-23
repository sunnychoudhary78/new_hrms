import 'package:lms/core/network/api_endpoints.dart';
import 'package:lms/core/network/api_service.dart';

class MeetingsApiService {
  final ApiService api;

  MeetingsApiService(this.api);

  Future<dynamic> listMeetings({String tab = 'upcoming'}) {
    return api.get(ApiEndpoints.meetings, queryParams: {'tab': tab});
  }

  Future<dynamic> getMeeting(String id) {
    return api.get('${ApiEndpoints.meetings}/$id');
  }

  Future<dynamic> createMeeting(Map<String, dynamic> body) {
    return api.post(ApiEndpoints.meetings, body);
  }

  Future<dynamic> updateMeeting(String id, Map<String, dynamic> body) {
    return api.patch('${ApiEndpoints.meetings}/$id', body);
  }

  Future<dynamic> cancelMeeting(String id) {
    return api.post('${ApiEndpoints.meetings}/$id/cancel', {});
  }

  Future<dynamic> setParticipants(String id, List<String> participantIds) {
    return api.post('${ApiEndpoints.meetings}/$id/participants', {
      'participant_ids': participantIds,
    });
  }

  Future<dynamic> getJoinUrl(String id) {
    return api.post('${ApiEndpoints.meetings}/$id/join-url', {});
  }

  Future<dynamic> createGuestInvite(String id, Map<String, dynamic> body) {
    return api.post('${ApiEndpoints.meetings}/$id/guest-invite', body);
  }

  Future<dynamic> getMinimalEmployees() {
    return api.get(ApiEndpoints.employeesMinimal);
  }

  Future<dynamic> getCompanySettings() {
    return api.get(ApiEndpoints.companySettings);
  }
}
