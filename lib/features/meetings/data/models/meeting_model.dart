const meetingWeekdays = <int, String>{
  1: 'Mon',
  2: 'Tue',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
  6: 'Sat',
  7: 'Sun',
};

class MeetingUser {
  final String id;
  final String name;
  final String? email;

  const MeetingUser({required this.id, required this.name, this.email});

  factory MeetingUser.fromJson(Map<String, dynamic> json) {
    return MeetingUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
    );
  }
}

class MeetingParticipant {
  final String id;
  final String meetingId;
  final String userId;
  final String role;
  final bool isActive;
  final MeetingUser? user;

  const MeetingParticipant({
    required this.id,
    required this.meetingId,
    required this.userId,
    required this.role,
    required this.isActive,
    this.user,
  });

  factory MeetingParticipant.fromJson(Map<String, dynamic> json) {
    return MeetingParticipant(
      id: json['id']?.toString() ?? '',
      meetingId: json['meeting_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'attendee',
      isActive: json['is_active'] != false,
      user: json['user'] is Map
          ? MeetingUser.fromJson(Map<String, dynamic>.from(json['user'] as Map))
          : null,
    );
  }

  String get displayName {
    final n = user?.name.trim() ?? '';
    return n.isNotEmpty ? n : userId;
  }
}

class MeetingEmployee {
  final String id;
  final String name;

  const MeetingEmployee({required this.id, required this.name});

  factory MeetingEmployee.fromJson(Map<String, dynamic> json) {
    return MeetingEmployee(
      id: (json['id'] ?? json['user_id'])?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class MeetingJoinInfo {
  final String url;
  final String? meetingId;
  final String? role;
  final bool lobby;
  final String? note;

  const MeetingJoinInfo({
    required this.url,
    this.meetingId,
    this.role,
    this.lobby = false,
    this.note,
  });

  factory MeetingJoinInfo.fromJson(Map<String, dynamic> json) {
    return MeetingJoinInfo(
      url: json['url']?.toString() ?? '',
      meetingId: json['meeting_id']?.toString(),
      role: json['role']?.toString(),
      lobby: json['lobby'] == true,
      note: json['note']?.toString(),
    );
  }

  bool get isHost => role == 'host';
}

class MeetingGuestInvite {
  final String inviteUrl;
  final String? inviteToken;
  final String? role;
  final bool jwtRequired;
  final bool lobby;
  final String? note;

  const MeetingGuestInvite({
    required this.inviteUrl,
    this.inviteToken,
    this.role,
    this.jwtRequired = true,
    this.lobby = true,
    this.note,
  });

  factory MeetingGuestInvite.fromJson(Map<String, dynamic> json) {
    return MeetingGuestInvite(
      inviteUrl: json['invite_url']?.toString() ?? '',
      inviteToken: json['invite_token']?.toString(),
      role: json['role']?.toString(),
      jwtRequired: json['jwt_required'] != false,
      lobby: json['lobby'] != false,
      note: json['note']?.toString(),
    );
  }
}

class MeetingsListResult {
  final List<Meeting> meetings;
  final bool canCreate;
  final bool canManage;

  const MeetingsListResult({
    required this.meetings,
    this.canCreate = false,
    this.canManage = false,
  });
}

class Meeting {
  final String id;
  final String? companyId;
  final String? createdBy;
  final String title;
  final String? description;
  final String type;
  final DateTime? startsAt;
  final int durationMinutes;
  final String? recurrenceTime;
  final List<int> recurrenceDays;
  final String timezone;
  final String? meetingProvider;
  final String? meetingId;
  final String? meetLink;
  final String status;
  final bool isActive;
  final MeetingUser? creator;
  final List<MeetingParticipant> participants;

  const Meeting({
    required this.id,
    this.companyId,
    this.createdBy,
    required this.title,
    this.description,
    required this.type,
    this.startsAt,
    required this.durationMinutes,
    this.recurrenceTime,
    this.recurrenceDays = const [],
    this.timezone = 'Asia/Kolkata',
    this.meetingProvider,
    this.meetingId,
    this.meetLink,
    required this.status,
    this.isActive = true,
    this.creator,
    this.participants = const [],
  });

  bool get isRecurring => type == 'recurring';
  bool get isInstant => type == 'instant';
  bool get isOneTime => type == 'one_time';
  bool get isCancelled => status == 'cancelled';
  bool get isEnded => status == 'ended';
  bool get isScheduled => status == 'scheduled';

  String get typeLabel {
    switch (type) {
      case 'recurring':
        return 'Recurring';
      case 'instant':
        return 'Instant';
      default:
        return 'One-time';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'cancelled':
        return 'Cancelled';
      case 'ended':
        return 'Ended';
      default:
        return 'Scheduled';
    }
  }

  bool isHostOf(String? userId) {
    if (userId == null || userId.isEmpty || createdBy == null) return false;
    return createdBy == userId;
  }

  List<MeetingParticipant> get activeParticipants =>
      participants.where((p) => p.isActive).toList();

  List<String> get attendeeUserIds => activeParticipants
      .where((p) => p.role == 'attendee')
      .map((p) => p.userId)
      .where((id) => id.isNotEmpty)
      .toList();

  String formatWhen() {
    if (isRecurring) {
      final time = (recurrenceTime ?? '').padRight(5).substring(0, 5).trim();
      final labels = recurrenceDays
          .map((d) => meetingWeekdays[d] ?? d.toString())
          .join(', ');
      final days = labels.isEmpty ? 'Weekdays' : labels;
      final tz = timezone.isNotEmpty ? timezone : '';
      return tz.isEmpty ? '$time · $days' : '$time · $days ($tz)';
    }
    if (startsAt == null) return '—';
    final local = startsAt!.toLocal();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final wd = weekdays[local.weekday - 1];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$wd, ${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]}, $hh:$mm';
  }

  factory Meeting.fromJson(Map<String, dynamic> json) {
    DateTime? startsAt;
    final rawStart = json['starts_at'];
    if (rawStart is String && rawStart.isNotEmpty) {
      startsAt = DateTime.tryParse(rawStart)?.toUtc();
    }

    List<int> days = const [];
    final rawDays = json['recurrence_days'];
    if (rawDays is List) {
      days = rawDays
          .map((d) => int.tryParse(d.toString()) ?? 0)
          .where((d) => d >= 1 && d <= 7)
          .toList();
    }

    final rawParticipants = json['participants'];
    final participants = <MeetingParticipant>[];
    if (rawParticipants is List) {
      for (final p in rawParticipants) {
        if (p is Map) {
          participants.add(
            MeetingParticipant.fromJson(Map<String, dynamic>.from(p)),
          );
        }
      }
    }

    return Meeting(
      id: json['id']?.toString() ?? '',
      companyId: json['company_id']?.toString(),
      createdBy: json['created_by']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      type: json['type']?.toString() ?? 'one_time',
      startsAt: startsAt,
      durationMinutes: int.tryParse(json['duration_minutes']?.toString() ?? '') ?? 30,
      recurrenceTime: json['recurrence_time']?.toString(),
      recurrenceDays: days,
      timezone: json['timezone']?.toString() ?? 'Asia/Kolkata',
      meetingProvider: json['meeting_provider']?.toString(),
      meetingId: json['meeting_id']?.toString(),
      meetLink: json['meet_link']?.toString(),
      status: json['status']?.toString() ?? 'scheduled',
      isActive: json['is_active'] != false,
      creator: json['creator'] is Map
          ? MeetingUser.fromJson(Map<String, dynamic>.from(json['creator'] as Map))
          : null,
      participants: participants,
    );
  }
}

Map<String, dynamic> meetingResponseMap(dynamic res) {
  if (res is Map<String, dynamic>) return res;
  if (res is Map) return Map<String, dynamic>.from(res);
  return {};
}

List<Meeting> meetingsFromListResponse(dynamic res) {
  final map = meetingResponseMap(res);
  dynamic raw = map['data'];
  if (raw is Map) {
    raw = raw['data'] ?? raw['meetings'] ?? raw['rows'];
  }
  if (raw is! List) return const [];
  final out = <Meeting>[];
  for (final e in raw) {
    if (e is Map) {
      out.add(Meeting.fromJson(Map<String, dynamic>.from(e)));
    }
  }
  return out;
}

MeetingsListResult meetingsListFromResponse(dynamic res) {
  final map = meetingResponseMap(res);
  final meta = map['meta'];
  var canCreate = false;
  var canManage = false;
  if (meta is Map) {
    canCreate = meta['canCreate'] == true;
    canManage = meta['canManage'] == true;
  }
  return MeetingsListResult(
    meetings: meetingsFromListResponse(res),
    canCreate: canCreate,
    canManage: canManage,
  );
}

Meeting? meetingFromResponse(dynamic res) {
  final map = meetingResponseMap(res);
  dynamic raw = map['data'] ?? map;
  if (raw is Map) {
    return Meeting.fromJson(Map<String, dynamic>.from(raw));
  }
  return null;
}

List<MeetingEmployee> employeesFromMinimalResponse(dynamic res) {
  final map = meetingResponseMap(res);
  dynamic raw = map['employees'] ?? map['data'];
  if (raw is Map) {
    raw = raw['employees'] ?? raw['data'];
  }
  if (raw is! List) return const [];
  final out = <MeetingEmployee>[];
  for (final e in raw) {
    if (e is Map) {
      final emp = MeetingEmployee.fromJson(Map<String, dynamic>.from(e));
      if (emp.id.isNotEmpty) out.add(emp);
    }
  }
  return out;
}
