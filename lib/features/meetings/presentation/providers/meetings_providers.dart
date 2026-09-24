import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/auth/auth_features.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/meetings/data/meetings_api_service.dart';
import 'package:lms/features/meetings/data/meetings_repo.dart';
import 'package:lms/features/meetings/data/models/meeting_model.dart';

final meetingsApiServiceProvider = Provider<MeetingsApiService>((ref) {
  return MeetingsApiService(ref.read(apiServiceProvider));
});

final meetingsRepositoryProvider = Provider<MeetingsRepository>((ref) {
  return MeetingsRepository(ref.read(meetingsApiServiceProvider));
});

class MeetingsTabNotifier extends Notifier<String> {
  @override
  String build() => 'upcoming';

  void select(String tab) {
    if (state == tab) return;
    state = tab;
  }
}

final meetingsTabProvider = NotifierProvider<MeetingsTabNotifier, String>(
  MeetingsTabNotifier.new,
);

final meetingsListProvider = FutureProvider.autoDispose<MeetingsListResult>((
  ref,
) async {
  final tab = ref.watch(meetingsTabProvider);
  return ref.read(meetingsRepositoryProvider).listMeetings(tab: tab);
});

void invalidateMeetingsCaches(WidgetRef ref, {String? meetingId}) {
  ref.invalidate(meetingsListProvider);
  if (meetingId != null && meetingId.isNotEmpty) {
    ref.invalidate(meetingDetailProvider(meetingId));
  }
}

bool isMeetingNotificationType(String? type) {
  final t = (type ?? '').trim().toLowerCase();
  return t.contains('meeting');
}

final meetingDetailProvider = FutureProvider.autoDispose.family<Meeting, String>(
  (ref, id) async {
    return ref.read(meetingsRepositoryProvider).getMeeting(id);
  },
);

final meetingEmployeesProvider =
    FutureProvider.autoDispose<List<MeetingEmployee>>((ref) async {
      return ref.read(meetingsRepositoryProvider).getMinimalEmployees();
    });

/// Same gate as web Sidebar: feature `meetings` + any of
/// `meeting.join` / `meeting.create` / `meeting.manage`.
final meetingsMenuVisibleProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  return canAccessMeetingsMenu(
    permissions: auth.permissions,
    features: auth.features,
    roleName: auth.roleName ?? auth.authUser?.role?.name,
    featuresLoaded: auth.featuresLoaded,
  );
});

final canCreateMeetingsProvider = Provider<bool>((ref) {
  final permissions = ref.watch(authProvider).permissions;
  final list = ref.watch(meetingsListProvider).asData?.value;
  return canCreateMeetings(permissions, metaCanCreate: list?.canCreate);
});

final canEditMeetingsProvider = Provider<bool>((ref) {
  return canEditMeetings(ref.watch(authProvider).permissions);
});

String? currentUserId(WidgetRef ref) {
  final auth = ref.read(authProvider);
  final fromAuth = auth.authUser?.id.trim();
  if (fromAuth != null && fromAuth.isNotEmpty) return fromAuth;
  final fromProfile = auth.profile?.userId?.trim();
  if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
  return null;
}
