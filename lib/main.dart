import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:upgrader/upgrader.dart';

import 'package:lms/app/app_routes.dart';
import 'package:lms/app/app_root.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/core/services/location_tracking_service.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/core/theme/app_theme_provider.dart';
import 'package:lms/core/theme/theme_mode_provider.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/onboarding/presentation/widgets/force_password_change_gate.dart';
import 'package:lms/features/meetings/presentation/widgets/meeting_webview_overlay.dart';

import 'package:lms/shared/widgets/global_error.dart';
import 'package:lms/shared/widgets/global_loader.dart';
import 'package:lms/shared/widgets/global_message.dart';
import 'package:lms/shared/widgets/global_sucess.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// iOS App Store lookup. Android uses [AppUpdateService] (Play In-App Update API).
final Upgrader _appUpgrader = Upgrader(
  durationUntilAlertAgain: const Duration(days: 1),
  debugLogging: kDebugMode,
  countryCode: 'IN',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocationTrackingService().initialize();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(Root(key: Root.rootKey));
}

/// ✅ ROOT is now StatefulWidget (NOT ConsumerWidget)
class Root extends StatefulWidget {
  const Root({super.key});

  static final GlobalKey<_RootState> rootKey = GlobalKey<_RootState>();

  @override
  State<Root> createState() => _RootState();

  /// Call this to restart app
  static void restartApp() {
    rootKey.currentState?.restart();
  }
}

class _RootState extends State<Root> {
  Key key = UniqueKey();

  void restart() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    /// ✅ ProviderScope recreated when key changes
    return ProviderScope(key: key, child: const MyApp());
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = ref.watch(appThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    final lightTheme = AppTheme.light(primaryColor).copyWith(
      textTheme: GoogleFonts.interTextTheme(
        AppTheme.light(primaryColor).textTheme,
      ).apply(
        bodyColor: AppColors.lightTitle,
        displayColor: AppColors.lightTitle,
      ),
    );
    final darkTheme = AppTheme.dark(primaryColor).copyWith(
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).apply(
        bodyColor: AppColors.darkTitle,
        displayColor: AppColors.darkTitle,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      navigatorKey: navigatorKey,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: _buildHome(),
      routes: AppRoutes.routes,
      builder: (context, child) {
        // Resolve the active theme here (builder context is not always themed).
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        final useDark = switch (themeMode) {
          ThemeMode.dark => true,
          ThemeMode.light => false,
          ThemeMode.system => platformBrightness == Brightness.dark,
        };
        final activeTheme = useDark ? darkTheme : lightTheme;
        AppColors.bindFromTheme(activeTheme);

        final overlay = ref.watch(globalLoadingProvider);
        final auth = ref.watch(authProvider);
        final showPasswordGate =
            auth.profile != null && auth.mustChangePassword;

        return Theme(
          data: activeTheme,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              MeetingPersistentHost(child: child!),
              if (overlay.isLoading) GlobalLoader(message: overlay.message),
              if (overlay.isSuccess) GlobalSuccess(message: overlay.message),
              if (overlay.isError) GlobalError(message: overlay.message),
              if (overlay.isMessage) GlobalMessage(message: overlay.message),
              if (showPasswordGate) const ForcePasswordChangeGate(),
            ],
          ),
        );
      },
    );
  }

  /// Android: Play In-App Update (versionCode). iOS: Upgrader (App Store version name).
  Widget _buildHome() {
    const appRoot = AppRoot();

    if (Platform.isAndroid) {
      return appRoot;
    }

    return UpgradeAlert(
      upgrader: _appUpgrader,
      navigatorKey: navigatorKey,
      showIgnore: false,
      showLater: true,
      child: appRoot,
    );
  }
}
