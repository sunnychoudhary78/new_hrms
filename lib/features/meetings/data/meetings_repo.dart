import 'package:lms/features/meetings/data/meetings_api_service.dart';
import 'package:lms/features/meetings/data/models/meeting_model.dart';

class MeetingsRepository {
  final MeetingsApiService api;

  MeetingsRepository(this.api);

  Future<MeetingsListResult> listMeetings({String tab = 'upcoming'}) async {
    final res = await api.listMeetings(tab: tab);
    return meetingsListFromResponse(res);
  }

  Future<Meeting> getMeeting(String id) async {
    final res = await api.getMeeting(id);
    final meeting = meetingFromResponse(res);
    if (meeting == null || meeting.id.isEmpty) {
      throw Exception('Meeting not found');
    }
    return meeting;
  }

  Future<Meeting> createMeeting(Map<String, dynamic> body) async {
    final res = await api.createMeeting(body);
    final meeting = meetingFromResponse(res);
    if (meeting == null || meeting.id.isEmpty) {
      throw Exception('Failed to create meeting');
    }
    return meeting;
  }

  Future<Meeting> updateMeeting(String id, Map<String, dynamic> body) async {
    final res = await api.updateMeeting(id, body);
    final meeting = meetingFromResponse(res);
    if (meeting == null || meeting.id.isEmpty) {
      throw Exception('Failed to update meeting');
    }
    return meeting;
  }

  Future<void> cancelMeeting(String id) async {
    await api.cancelMeeting(id);
  }

  Future<void> setParticipants(String id, List<String> participantIds) async {
    await api.setParticipants(id, participantIds);
  }

  Future<MeetingJoinInfo> getJoinUrl(String id) async {
    final res = await api.getJoinUrl(id);
    final map = meetingResponseMap(res);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;
    final info = MeetingJoinInfo.fromJson(data);
    if (info.url.isEmpty) {
      throw Exception('Could not get join link');
    }
    return info;
  }

  Future<MeetingGuestInvite> createGuestInvite(
    String id, {
    String? name,
    String? email,
    bool sendEmail = false,
  }) async {
    final body = <String, dynamic>{
      'name': (name == null || name.trim().isEmpty) ? 'Guest' : name.trim(),
      'send_email': sendEmail,
    };
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }
    final res = await api.createGuestInvite(id, body);
    final map = meetingResponseMap(res);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;
    final invite = MeetingGuestInvite.fromJson(data);
    if (invite.inviteUrl.isEmpty) {
      throw Exception('Could not create guest link');
    }
    return invite;
  }

  Future<List<MeetingEmployee>> getMinimalEmployees() async {
    final res = await api.getMinimalEmployees();
    return employeesFromMinimalResponse(res);
  }

  Future<Map<String, dynamic>> getCompanySettings() async {
    final res = await api.getCompanySettings();
    final map = meetingResponseMap(res);
    if (map['company'] == null && map['data'] is Map) {
      return Map<String, dynamic>.from(map['data'] as Map);
    }
    return map;
  }
}
