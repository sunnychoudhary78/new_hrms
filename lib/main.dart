import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lms/app/app_routes.dart';
import 'package:lms/app/app_root.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/core/services/location_tracking_service.dart';

import 'package:lms/core/theme/app_theme_provider.dart';
import 'package:lms/core/theme/theme_mode_provider.dart';

import 'package:lms/shared/widgets/global_error.dart';
import 'package:lms/shared/widgets/global_loader.dart';
import 'package:lms/shared/widgets/global_sucess.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocationTrackingService().initialize();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const Root());
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

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      themeMode: themeMode,
      navigatorKey: navigatorKey,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
      ),

      home: const AppRoot(),

      routes: AppRoutes.routes,

      builder: (context, child) {
        final overlay = ref.watch(globalLoadingProvider);

        return Stack(
          children: [
            child!,

            if (overlay.isLoading) GlobalLoader(message: overlay.message),

            if (overlay.isSuccess) GlobalSuccess(message: overlay.message),

            if (overlay.isError) GlobalError(message: overlay.message),
          ],
        );
      },
    );
  }
}
