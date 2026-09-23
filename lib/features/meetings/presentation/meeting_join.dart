import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/meetings/presentation/meetings_access.dart';
import 'package:lms/features/meetings/presentation/providers/meetings_providers.dart';
import 'package:lms/shared/utils/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> joinMeetingById(
  BuildContext context,
  WidgetRef ref,
  String meetingId,
) async {
  try {
    final info = await ref
        .read(meetingsRepositoryProvider)
        .getJoinUrl(meetingId);
    final uri = Uri.tryParse(info.url);
    if (uri == null) {
      if (context.mounted) {
        AppSnackbar.error(context, 'Could not get join link');
      }
      return false;
    }
    if (info.note != null && info.note!.trim().isNotEmpty && context.mounted) {
      AppSnackbar.info(context, info.note!);
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      AppSnackbar.error(context, 'Could not open Meet');
      return false;
    }
    return opened;
  } catch (e) {
    if (context.mounted) {
      AppSnackbar.error(context, cleanApiError(e));
    }
    return false;
  }
}
