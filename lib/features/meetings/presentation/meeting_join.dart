import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
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

String withJitsiDisplayName(String url, String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return url;
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  if (uri.fragment.contains('userInfo.displayName')) return url;
  final extra = 'userInfo.displayName="${Uri.encodeComponent(trimmed)}"';
  final fragment = uri.fragment.isEmpty ? extra : '${uri.fragment}&$extra';
  return uri.replace(fragment: fragment).toString();
}

Future<bool> joinMeetingById(
  BuildContext context,
  WidgetRef ref, {
  required String meetingId,
  String? title,
}) async {
  final session = ref.read(meetingSessionProvider);
  if (session.isFor(meetingId)) {
    ref.read(meetingSessionProvider.notifier).expand();
    return true;
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
    if (switchCall != true) return false;
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
      return false;
    }
    if (info.note != null && info.note!.trim().isNotEmpty && context.mounted) {
      AppSnackbar.info(context, info.note!);
    }
    final displayName = meetingUserDisplayName(ref);
    ref.read(meetingSessionProvider.notifier).start(
          meetingId: meetingId,
          joinUrl: withJitsiDisplayName(info.url, displayName),
          title: title,
          displayName: displayName,
        );
    return true;
  } catch (e) {
    ref.read(meetingSessionProvider.notifier).setConnecting(false);
    if (context.mounted) {
      AppSnackbar.error(context, cleanApiError(e));
    }
    return false;
  }
}
