import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_view.dart';
import 'package:lms/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:lms/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:lms/shared/widgets/app_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (_shown) return;
      _shown = true;

      final auth = ref.read(authProvider);
      final name = auth.profile?.associatesName?.split(' ').first ?? '';

      ref
          .read(globalLoadingProvider.notifier)
          .showMessage("Welcome back, $name 👋");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: "Home",
        showBack: false,
        actions: const [_NotificationIcon()],
      ),
      drawer: const AppDrawer(),
      body: const HomeDashboardView(),
    );
  }
}

class _NotificationIcon extends ConsumerWidget {
  const _NotificationIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          /// MAIN ICON (Increase tap area)
          IconButton(
            iconSize: 26,
            splashRadius: 26,
            padding: const EdgeInsets.all(12),
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
            },
          ),

          /// 🔴 Unread Badge (Does NOT block taps)
          if (unreadCount > 0)
            Positioned(
              right: 6,
              top: 6,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: scheme.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: TextStyle(
                      color: scheme.onError,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
