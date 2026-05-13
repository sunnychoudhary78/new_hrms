import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mark_attendance_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mobile_config_provider.dart';
import 'package:lms/features/home/presentation/providers/home_dashboard_proovider.dart';
import 'package:lms/features/home/presentation/widgets/attendance_overview_card.dart';
import 'package:lms/features/home/presentation/widgets/home_welcome_attendance_card.dart';
import 'package:lms/features/home/presentation/widgets/last_five_days_card.dart';

class HomeDashboardView extends ConsumerStatefulWidget {
  const HomeDashboardView({super.key});

  @override
  ConsumerState<HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends ConsumerState<HomeDashboardView> {
  @override
  void initState() {
    super.initState();

    /// 🔥 AUTO REFRESH WHEN SCREEN LOADS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  void _refreshAll() {
    ref.invalidate(homeDashboardProvider);
    ref.invalidate(markAttendanceProvider);
    ref.invalidate(mobileConfigProvider);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeDashboardProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),

      error: (e, _) => Center(child: Text('Error: $e')),

      data: (dashboard) {
        final scrollPhysics = defaultTargetPlatform == TargetPlatform.iOS
            ? const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              )
            : const AlwaysScrollableScrollPhysics();

        return RefreshIndicator(
          onRefresh: () async {
            _refreshAll();
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: ListView(
            physics: scrollPhysics,
            padding: const EdgeInsets.all(16),
            children: [
              HomeWelcomeAttendanceCard(
                name: dashboard.userName,
                role: dashboard.designation,
                imageUrl: dashboard.profileImageUrl,
              ),
              const SizedBox(height: 16),

              LastFiveDaysAttendanceCard(days: dashboard.lastFiveDays),
              const SizedBox(height: 16),

              AttendanceOverviewCard(dashboard: dashboard),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }
}
