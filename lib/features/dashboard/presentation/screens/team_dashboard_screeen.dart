import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/dashboard/presentation/providers/team_dashboard_proividers.dart';
import 'package:lms/features/dashboard/presentation/screens/employee_attendence_calender_screen.dart';
import 'package:lms/features/dashboard/presentation/widgets/team_analytics_section.dart';
import 'package:lms/features/dashboard/presentation/widgets/team_member_card.dart';
import 'package:lms/features/dashboard/presentation/widgets/team_overview_card.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';

class TeamDashboardScreen extends ConsumerStatefulWidget {
  const TeamDashboardScreen({super.key});

  @override
  ConsumerState<TeamDashboardScreen> createState() =>
      _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends ConsumerState<TeamDashboardScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(teamDashboardProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: AppColors.bg,
      appBar: AppAppBar(title: "Dashboard"),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(e.toString(), textAlign: TextAlign.center)),
        data: (dashboard) {
          final filtered = dashboard.employees.where((e) {
            final q = searchQuery.toLowerCase();
            return e.name.toLowerCase().contains(q) ||
                e.employeeId.toLowerCase().contains(q) ||
                e.email.toLowerCase().contains(q);
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PremiumFeatureHeader(
                        icon: Icons.groups_outlined,
                        title: "Team Dashboard",
                        subtitle:
                            "Monitor attendance health, productivity trends and your direct reports.",
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _searchBar(),
                      const SizedBox(height: AppSpacing.lg),

                      TeamOverviewCard(dashboard: dashboard),

                      const SizedBox(height: AppSpacing.lg),

                      TeamAnalyticsSection(dashboard: dashboard),

                      const SizedBox(height: AppSpacing.lg),

                      PremiumSectionTitle(
                        title: "Team Members (${filtered.length})",
                        subtitle: "Tap a member to open their attendance calendar.",
                      ),
                      const SizedBox(height: AppSpacing.md),

                      /// 👤 Team Members List
                      ...filtered.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: TeamMemberCard(
                            employee: e,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EmployeeAttendanceCalendarScreen(
                                        employee: e,
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: AppColors.cardDecoration(radius: AppRadius.lg),
      child: TextField(
        onChanged: (v) => setState(() => searchQuery = v),
        decoration: InputDecoration(
          icon: Icon(Icons.search_rounded, color: AppColors.muted),
          hintText: "Search team member...",
          hintStyle: TextStyle(color: AppColors.muted),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
