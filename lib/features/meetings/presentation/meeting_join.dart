import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/meetings/presentation/meetings_access.dart';
import 'package:lms/features/meetings/presentation/providers/meeting_session_provider.dart';
import 'package:lms/features/meetings/presentation/providers/meetings_providers.dart';
import 'package:lms/shared/utils/app_snackbar.dart';
import 'package:permission_handler/permission_handler.dart';

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
    ref
        .read(meetingSessionProvider.notifier)
        .start(meetingId: meetingId, joinUrl: info.url, title: title);
    return true;
  } catch (e) {
    ref.read(meetingSessionProvider.notifier).setConnecting(false);
    if (context.mounted) {
      AppSnackbar.error(context, cleanApiError(e));
    }
    return false;
  }
}
