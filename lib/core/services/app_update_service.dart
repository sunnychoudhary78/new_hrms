import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Checks the Play Store for updates using Google's In-App Update API.
///
/// Unlike [Upgrader], this detects updates when only [versionCode] changes
/// (e.g. 1.1.0+13 → 1.1.0+14). Requires the app to be installed from Play Store.
class AppUpdateService {
  AppUpdateService._();

  static bool _checkInProgress = false;
  static bool _dialogShownThisSession = false;

  static Future<void> checkAndroidPlayStoreUpdate(BuildContext context) async {
    if (!Platform.isAndroid || _checkInProgress || _dialogShownThisSession) {
      return;
    }

    _checkInProgress = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (kDebugMode) {
        debugPrint(
          'AppUpdateService: availability=${info.updateAvailability}, '
          'immediate=${info.immediateUpdateAllowed}, '
          'flexible=${info.flexibleUpdateAllowed}',
        );
      }

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (!context.mounted) return;
      _dialogShownThisSession = true;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update available'),
          content: const Text(
            'A new version of HRMS is available on the Play Store. '
            'Please update to get the latest features and fixes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _startUpdate(info);
              },
              child: const Text('Update now'),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('AppUpdateService: Play update check failed: $e\n$stackTrace');
      }
    } finally {
      _checkInProgress = false;
    }
  }

  static Future<void> _startUpdate(AppUpdateInfo info) async {
    try {
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppUpdateService: update flow failed: $e');
      }
    }
  }
}
