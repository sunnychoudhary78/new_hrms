import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lms/core/providers/user_data_invalidation.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/home/presentation/widgets/drawer_item_tile.dart';
import 'package:lms/features/kra/presentation/kra_route_args.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer>
    with TickerProviderStateMixin {
  bool _isLeaveExpanded = false;
  bool _isAttendanceExpanded = false;
  bool _isExpenseExpanded = false;
  bool _isResignationExpanded = false;
  bool _isKraExpanded = false;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name;
    final authState = ref.watch(authProvider);

    final permissions = authState.permissions;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    // ================= ROLE DETECTION =================

    // Expense roles
    final isExpenseManager = permissions.contains('expense.manager');
    final isExpenseHod = permissions.contains('expense.hod');
    final isAccounts = permissions.contains('expense.accounts');

    // Resignation roles
    final isResignationManager = permissions.contains('resignation.manager');
    final isResignationHod = permissions.contains('resignation.hod');
    final isResignationHr = permissions.contains('resignation.hr');

    // Common permissions
    final hasLeaveApprove = permissions.contains('leave.request.approve');
    final hasAnyKraPermission = permissions.any((p) => p.startsWith('kra.'));
    final canViewMyKra = permissions.contains('kra.myrating');
    final canViewTeamKra = permissions.contains('kra.teamrating');
    final canViewDepartmentKra = permissions.contains('kra.department');
    final canViewAllKra = permissions.contains('kra.allrating');
    final canManageKra = permissions.contains('kra.manage');

    final scheme = Theme.of(context).colorScheme;
    final companyLogo = authState.companyLogoUrl;

    final drawerRadius = Radius.circular(isIOS ? 16 : 24);

    int index = 0;

    return Drawer(
      backgroundColor: scheme.surface,
      elevation: isIOS ? 6 : 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: drawerRadius,
          bottomRight: drawerRadius,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: isIOS
                    ? const BouncingScrollPhysics()
                    : const ClampingScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeader(companyLogo),

                    const SizedBox(height: 10),

                    // ================= HOME =================
                    DrawerTile(
                      index: index++,
                      icon: Icons.home_rounded,
                      title: "Home",
                      isActive: route == "/home",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          "/home",
                          (route) => false,
                        );
                      },
                    ),

                    // ================= PROFILE =================
                    DrawerTile(
                      index: index++,
                      icon: Icons.person,
                      title: "Profile",
                      isActive: route == "/profile",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, "/profile");
                      },
                    ),

                    // ================= ATTENDANCE =================
                    _buildExpandable(
                      index: index++,
                      title: "Attendance",
                      icon: Icons.access_time_rounded,
                      expanded: _isAttendanceExpanded,
                      onTap: () => setState(
                        () => _isAttendanceExpanded = !_isAttendanceExpanded,
                      ),
                      subItems: [
                        _subItem("Mark Attendance", "/mark-attendance"),
                        _subItem("View Attendance", "/view-attendance"),
                        _subItem("View Corrections", "/view-corrections"),
                        if (hasLeaveApprove)
                          _subItem(
                            "Attendance Correction",
                            "/correct-attendance",
                          ),
                      ],
                    ),

                    // ================= LEAVE =================
                    _buildExpandable(
                      index: index++,
                      title: "Leave",
                      icon: Icons.beach_access_rounded,
                      expanded: _isLeaveExpanded,
                      onTap: () =>
                          setState(() => _isLeaveExpanded = !_isLeaveExpanded),
                      subItems: [
                        _subItem("Leave Balance", "/leave-balance"),
                        _subItem("Leave Apply", "/leave-apply"),
                        _subItem("Leave Status", "/leave-status"),
                        if (hasLeaveApprove)
                          _subItem("Leave Approve/Reject", "/leave-approve"),
                      ],
                    ),

                    // ================= TEAM DASHBOARD =================
                    if (hasLeaveApprove)
                      DrawerTile(
                        index: index++,
                        icon: Icons.dashboard_rounded,
                        title: "Team Dashboard",
                        isActive: route == "/team-dashboard",
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, "/team-dashboard");
                        },
                      ),

                    // ================= KRA / KPI =================
                    if (hasAnyKraPermission)
                      _buildExpandable(
                        index: index++,
                        title: "KRA / KPI",
                        icon: Icons.track_changes_rounded,
                        expanded: _isKraExpanded,
                        onTap: () =>
                            setState(() => _isKraExpanded = !_isKraExpanded),
                        subItems: [
                          if (canManageKra)
                            _kraSubItem("Create KRA", KraRouteArgs.createKra),
                          if (canViewMyKra)
                            _kraSubItem("My KRA", KraRouteArgs.myRating),
                          if (canViewTeamKra || canManageKra)
                            _kraSubItem("Team Rating", KraRouteArgs.teamRating),
                          if (canViewDepartmentKra || canManageKra)
                            _kraSubItem(
                              "Department Rating",
                              KraRouteArgs.departmentRating,
                            ),
                          if (canViewAllKra)
                            _kraSubItem("All Ratings", KraRouteArgs.allRatings),
                          if (canManageKra)
                            _kraSubItem("KRA Setup", KraRouteArgs.setup),
                        ],
                      ),

                    // ================= EXPENSES (FIXED) =================
                    _buildExpandable(
                      index: index++,
                      title: "Expenses",
                      icon: Icons.receipt_long_rounded,
                      expanded: _isExpenseExpanded,
                      onTap: () => setState(
                        () => _isExpenseExpanded = !_isExpenseExpanded,
                      ),
                      subItems: [
                        // Always visible for every authenticated user
                        _subItem("My Expenses", "/expenses/my"),

                        // Dashboard is only for approver roles
                        if (isExpenseManager || isExpenseHod || isAccounts)
                          _subItem("Expenses Dashboard", "/expenses-dashboard"),
                      ],
                    ),

                    // ================= PAYSLIP =================
                    DrawerTile(
                      index: index++,
                      icon: Icons.payment,
                      title: "Payslip",
                      isActive: route == "/payslip",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, "/payslip");
                      },
                    ),

                    // ================= RESIGNATION (NEW) =================
                    _buildExpandable(
                      index: index++,
                      title: "Resignation",
                      icon: Icons.exit_to_app_rounded,
                      expanded: _isResignationExpanded,
                      onTap: () => setState(
                        () => _isResignationExpanded = !_isResignationExpanded,
                      ),
                      subItems: [
                        // ✅ ALWAYS VISIBLE
                        _subItem("My Resignation", "/resignation/my"),

                        // ✅ Only for approvers
                        if (isResignationManager ||
                            isResignationHod ||
                            isResignationHr)
                          _subItem(
                            "Resignation Dashboard",
                            "/resignation-dashboard",
                          ),
                      ],
                    ),

                    // ================= SETTINGS =================
                    DrawerTile(
                      index: index++,
                      icon: Icons.settings,
                      title: "Settings",
                      isActive: route == "/settings",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, "/settings");
                      },
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            Divider(color: scheme.outlineVariant),

            // ================= LOGOUT =================
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              child: DrawerTile(
                index: index++,
                icon: Icons.logout_rounded,
                title: "Logout",
                onTap: () async {
                  // Clear cached user data before ProviderScope restart (logout).
                  invalidateAllUserScopedData(ref);
                  await ref.read(authProvider.notifier).logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================

  Widget _buildHeader(String companyLogo) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color startColor = isDark ? const Color(0xFF1E1E2E) : scheme.primary;

    final Color endColor = isDark
        ? const Color(0xFF2A2A40)
        : scheme.primaryContainer;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [startColor, endColor]),
      ),
      child: Center(
        child: companyLogo.isNotEmpty
            ? Image.network(companyLogo, height: 60)
            : const SizedBox(),
      ),
    ).animate().fade().slideY(begin: -.15);
  }

  // ================= EXPANDABLE =================

  Widget _buildExpandable({
    required int index,
    required String title,
    required IconData icon,
    required bool expanded,
    required VoidCallback onTap,
    required List<Widget> subItems,
  }) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return Column(
      children: [
        DrawerTile(
          index: index,
          icon: icon,
          title: title,
          onTap: onTap,
          trailing: AnimatedRotation(
            turns: expanded ? .5 : 0,
            duration: const Duration(milliseconds: 250),
            child: Icon(
              Icons.keyboard_arrow_down,
              size: isIOS ? 22 : 24,
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: expanded ? Column(children: subItems) : const SizedBox(),
        ),
      ],
    );
  }

  void _goToKra(KraRouteArgs args) {
    final isAlreadyKra = ModalRoute.of(context)?.settings.name == "/kra";
    Navigator.pop(context);
    if (isAlreadyKra) {
      Navigator.pushReplacementNamed(context, "/kra", arguments: args);
    } else {
      Navigator.pushNamed(context, "/kra", arguments: args);
    }
  }

  /// KRA / KPI: same route, different [KraRouteArgs] — stay on one `/kra` if already there.
  Widget _kraSubItem(String title, KraRouteArgs args) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 14, top: 4, bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(isIOS ? 8 : 10),
        splashFactory: isIOS
            ? NoSplash.splashFactory
            : InkSplash.splashFactory,
        onTap: () => _goToKra(args),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subItem(String title, String route) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 14, top: 4, bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(isIOS ? 8 : 10),
        splashFactory: isIOS
            ? NoSplash.splashFactory
            : InkSplash.splashFactory,
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, route);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
            ],
          ),
        ),
      ),
    );
  }
}
