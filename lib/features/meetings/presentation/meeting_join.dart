import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/meetings/data/models/meeting_model.dart';
import 'package:lms/features/meetings/presentation/meetings_access.dart';
import 'package:lms/features/meetings/presentation/providers/meeting_session_provider.dart';
import 'package:lms/features/meetings/presentation/providers/meetings_providers.dart';
import 'package:lms/shared/utils/app_snackbar.dart';
import 'package:permission_handler/permission_handler.dart';

String meetingUserDisplayName(WidgetRef ref) {
  final auth = ref.read(authProvider);
  final fromProfile = auth.profile?.associatesName?.trim();
  if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
  final fromUser = auth.authUser?.name.trim();
  if (fromUser != null && fromUser.isNotEmpty) return fromUser;
  return '';
}

/// Jitsi UI sound ids muted in the in-app WebView (join / leave / chat / etc.).
/// Remote participant voice/video is unaffected — only bundled `/sounds/*` clips.
const jitsiDisabledUiSounds = <String>[
  'PARTICIPANT_JOINED_SOUND',
  'PARTICIPANT_LEFT_SOUND',
  'INCOMING_MSG_SOUND',
  'OUTGOING_CALL_EXPIRED_SOUND',
  'OUTGOING_CALL_REJECTED_SOUND',
  'OUTGOING_CALL_RINGING_SOUND',
  'OUTGOING_CALL_START_SOUND',
  'RAISE_HAND_SOUND',
  'REACTION_SOUND',
  'TALK_WHILE_MUTED_SOUND',
  'NO_AUDIO_SIGNAL_SOUND',
  'E2EE_ON_SOUND',
  'E2EE_OFF_SOUND',
  'RECORDING_ON_SOUND',
  'RECORDING_OFF_SOUND',
  'TRANSCRIPTION_ON_SOUND',
  'TRANSCRIPTION_OFF_SOUND',
  'RECORDING_AND_TRANSCRIPTION_ON_SOUND',
  'RECORDING_AND_TRANSCRIPTION_OFF_SOUND',
  'LIVE_STREAMING_ON_SOUND',
  'LIVE_STREAMING_OFF_SOUND',
];

/// Jitsi reads these from the URL hash before the app boots.
///
/// They must be on the raw URL. [Uri.replace] percent-encodes the fragment
/// and Jitsi then ignores `disableDeepLinking`, so Android WebView is sent
/// to the close/welcome page and the meeting overlay closes.
String withJitsiJoinOverrides(
  String url,
  String name, {
  String? avatarUrl,
}) {
  final hash = url.indexOf('#');
  final base = hash == -1 ? url : url.substring(0, hash);
  final existing = hash == -1 ? '' : url.substring(hash + 1);
  final parts = <String>[
    if (!existing.contains('config.disableDeepLinking'))
      'config.disableDeepLinking=true',
    if (!existing.contains('config.deeplinking.disabled'))
      'config.deeplinking.disabled=true',
    // Mute Meet UI tones (join ding, chat, etc.) — not remote call audio.
    if (!existing.contains('config.disableSounds'))
      'config.disableSounds=true',
    if (!existing.contains('config.disableRecordAudioNotification'))
      'config.disableRecordAudioNotification=true',
    // Raw JSON (not URI-encoded) — Jitsi parseURLParams JSON.parses `[` values.
    if (!existing.contains('config.disabledSounds'))
      'config.disabledSounds=[${jitsiDisabledUiSounds.map((s) => '"$s"').join(',')}]',
  ];
  final trimmed = name.trim();
  if (trimmed.isNotEmpty && !existing.contains('userInfo.displayName')) {
    parts.add('userInfo.displayName="${Uri.encodeComponent(trimmed)}"');
  }
  final avatar = avatarUrl?.trim() ?? '';
  if (avatar.isNotEmpty && !existing.contains('userInfo.avatarURL')) {
    parts.add('userInfo.avatarURL="${Uri.encodeComponent(avatar)}"');
  }
  if (parts.isEmpty) return url;
  final fragment = existing.isEmpty
      ? parts.join('&')
      : '$existing&${parts.join('&')}';
  return '$base#$fragment';
}

/// Starts or returns to a meeting WebView session.
///
/// Returns join info when a fresh join-url was minted (so callers can show
/// the host/attendee [MeetingJoinInfo.note]). Returns `null` when cancelled,
/// failed, or when simply expanding an existing in-call session.
Future<MeetingJoinInfo?> joinMeetingById(
  BuildContext context,
  WidgetRef ref, {
  required String meetingId,
  String? title,
  bool showNoteSnackbar = true,
}) async {
  final session = ref.read(meetingSessionProvider);
  if (session.isFor(meetingId)) {
    ref.read(meetingSessionProvider.notifier).expand();
    return null;
  }

  if (session.isActive && session.meetingId != meetingId) {
    final switchCall = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave current meeting?'),
        content: const Text(
          'You are already in another meeting. Join this one instead?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (switchCall != true) return null;
    ref.read(meetingSessionProvider.notifier).end();
  }

  try {
    await Permission.camera.request();
    await Permission.microphone.request();
  } catch (_) {}

  ref.read(meetingSessionProvider.notifier).setConnecting(true);
  try {
    final info = await ref
        .read(meetingsRepositoryProvider)
        .getJoinUrl(meetingId);
    if (info.url.isEmpty) {
      if (context.mounted) {
        AppSnackbar.error(context, 'Could not get join link');
      }
      ref.read(meetingSessionProvider.notifier).setConnecting(false);
      return null;
    }
    if (showNoteSnackbar &&
        info.note != null &&
        info.note!.trim().isNotEmpty &&
        context.mounted) {
      AppSnackbar.info(context, info.note!);
    }
    final displayName = meetingUserDisplayName(ref);
    final avatarUrl = ref.read(authProvider).profileUrl.trim();
    ref.read(meetingSessionProvider.notifier).start(
          meetingId: meetingId,
          joinUrl: withJitsiJoinOverrides(
            info.url,
            displayName,
            avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
          ),
          title: title,
          displayName: displayName,
        );
    return info;
  } catch (e) {
    ref.read(meetingSessionProvider.notifier).setConnecting(false);
    if (context.mounted) {
      AppSnackbar.error(context, cleanApiError(e));
    }
    return null;
  }
}
