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
import 'package:lms/shared/widgets/global_message.dart';
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

        scaffoldBackgroundColor: Colors.grey.shade50,

        /// ✅ INPUT FIELDS (TextField, Dropdown, etc.)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(width: 1.5),
          ),
        ),

        /// ✅ CARD THEME (your sections will look premium)
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.zero,
        ),

        /// ✅ BUTTON THEME (all ElevatedButtons upgraded)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
        ),
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

        /// ✅ INPUTS
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white24),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(width: 1.5),
          ),
        ),

        /// ✅ CARD
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.zero,
        ),

        /// ✅ BUTTON
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
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

            if (overlay.isMessage) GlobalMessage(message: overlay.message),
          ],
        );
      },
    );
  }
}
