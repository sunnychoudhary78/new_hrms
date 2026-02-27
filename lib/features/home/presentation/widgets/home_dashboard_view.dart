import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mark_attendance_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mobile_config_provider.dart';
import 'package:lms/features/home/presentation/providers/home_dashboard_proovider.dart';
import 'package:lms/features/home/presentation/widgets/attendance_overview_card.dart';
import 'package:lms/features/home/presentation/widgets/home_welcome_attendance_card.dart';
import 'package:lms/features/home/presentation/widgets/last_five_days_card.dart';

class HomeDashboardView extends ConsumerWidget {
  const HomeDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeDashboardProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),

      error: (e, _) => Center(child: Text('Error: $e')),

      data: (dashboard) {
        return RefreshIndicator(
          onRefresh: () async {
            // Refresh dashboard
            ref.invalidate(homeDashboardProvider);

            // Refresh attendance sessions
            ref.invalidate(markAttendanceProvider);

            // Refresh mobile config (THIS IS THE MAIN FIX)
            ref.invalidate(mobileConfigProvider);

            // Small delay to allow rebuild smoothness
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HomeWelcomeAttendanceCard(
                name: dashboard.userName,
                role: dashboard.designation,
                imageUrl: dashboard.profileImageUrl, // optional
              ),

              const SizedBox(height: 16),
              LastFiveDaysAttendanceCard(days: dashboard.lastFiveDays),
              const SizedBox(height: 16),

              AttendanceOverviewCard(dashboard: dashboard),
              SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }
}
