import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lms/core/network/api_constants.dart';
import 'package:lms/core/providers/user_data_invalidation.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/home/presentation/widgets/drawer_item_tile.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';
import 'package:lms/features/kra/presentation/kra_route_args.dart';
import 'package:lms/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:lms/features/meetings/presentation/providers/meetings_providers.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
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
    final dayOneFinished = ref.watch(dayOneFinishedProvider);

    final isExpenseManager = permissions.contains('expense.manager');
    final isExpenseHod = permissions.contains('expense.hod');
    final isAccounts = permissions.contains('expense.accounts');
    final isResignationManager = permissions.contains('resignation.manager');
    final isResignationHod = permissions.contains('resignation.hod');
    final isResignationHr = permissions.contains('resignation.hr');
    final hasLeaveApprove = permissions.contains('leave.request.approve');
    final hasAnyKraPermission = permissions.any((p) => p.startsWith('kra.'));
    final canViewMyKra = permissions.contains('kra.myrating');
    final canViewTeamKra = permissions.contains('kra.teamrating');
    final canViewDepartmentKra = permissions.contains('kra.department');
    final canViewAllKra = permissions.contains('kra.allrating');
    final canManageKra = permissions.contains('kra.manage');
    final showMeetings = ref.watch(meetingsMenuVisibleProvider);

    final profile = authState.profile;
    final employeeName = _titleCase(profile?.associatesName ?? 'Employee');
    final designation = _designationLabel(profile?.designation);
    final empCode = (profile?.payrollCode?.trim().isNotEmpty ?? false)
        ? profile!.payrollCode!.trim()
        : (profile?.userId?.trim().isNotEmpty ?? false)
            ? profile!.userId!.trim()
            : null;
    final imageUrl = (profile?.profilePicture != null &&
            profile!.profilePicture!.trim().isNotEmpty)
        ? ApiConstants.imageBaseUrl + profile.profilePicture!
        : null;

    int index = 0;

    return Drawer(
      backgroundColor: const Color(0xFFF7F9FC),
      elevation: isIOS ? 6 : 12,
      width: MediaQuery.sizeOf(context).width * 0.72,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(isIOS ? 18 : 28),
          bottomRight: Radius.circular(isIOS ? 18 : 28),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: isIOS
                    ? const BouncingScrollPhysics()
                    : const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(
                      name: employeeName,
                      designation: designation,
                      empCode: empCode,
                      imageUrl: imageUrl,
                    ),
                    const SizedBox(height: 18),

                    _menuGroup(
                      children: [
                        DrawerTile(
                          index: index++,
                          icon: Icons.home_rounded,
                          title: 'Home',
                          accent: HomeDashColors.accentBlue,
                          isActive: route == '/home',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/home',
                              (_) => false,
                            );
                          },
                        ),
                        if (!dayOneFinished)
                          DrawerTile(
                            index: index++,
                            icon: Icons.flag_rounded,
                            title: 'Day-one Guide',
                            accent: HomeDashColors.accentBlue,
                            isActive: route == '/day-one',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/day-one');
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    _menuGroup(
                      children: [
                        _buildExpandable(
                          index: index++,
                          title: 'Attendance',
                          icon: Icons.access_time_filled_rounded,
                          accent: HomeDashColors.accentBlue,
                          expanded: _isAttendanceExpanded,
                          isActive: route == '/mark-attendance' ||
                              route == '/view-attendance' ||
                              route == '/view-corrections' ||
                              route == '/correct-attendance',
                          onTap: () => setState(
                            () =>
                                _isAttendanceExpanded = !_isAttendanceExpanded,
                          ),
                          subItems: [
                            _subItem(
                              'Mark Attendance',
                              '/mark-attendance',
                              Icons.fingerprint_rounded,
                            ),
                            _subItem(
                              'View Attendance',
                              '/view-attendance',
                              Icons.calendar_month_rounded,
                            ),
                            _subItem(
                              'View Corrections',
                              '/view-corrections',
                              Icons.edit_calendar_rounded,
                            ),
                            if (hasLeaveApprove)
                              _subItem(
                                'Attendance Correction',
                                '/correct-attendance',
                                Icons.rule_rounded,
                              ),
                          ],
                        ),
                        _buildExpandable(
                          index: index++,
                          title: 'Leave',
                          icon: Icons.park_rounded,
                          accent: HomeDashColors.accentBlue,
                          expanded: _isLeaveExpanded,
                          isActive: route == '/leave-balance' ||
                              route == '/leave-apply' ||
                              route == '/leave-status' ||
                              route == '/leave-approve',
                          onTap: () => setState(
                            () => _isLeaveExpanded = !_isLeaveExpanded,
                          ),
                          subItems: [
                            _subItem(
                              'Leave Balance',
                              '/leave-balance',
                              Icons.eco_rounded,
                            ),
                            _subItem(
                              'Leave Apply',
                              '/leave-apply',
                              Icons.event_available_rounded,
                            ),
                            _subItem(
                              'Leave Status',
                              '/leave-status',
                              Icons.pending_actions_rounded,
                            ),
                            if (hasLeaveApprove)
                              _subItem(
                                'Leave Approve/Reject',
                                '/leave-approve',
                                Icons.fact_check_rounded,
                              ),
                          ],
                        ),
                        if (hasLeaveApprove)
                          DrawerTile(
                            index: index++,
                            icon: Icons.groups_rounded,
                            title: 'Team Dashboard',
                            accent: HomeDashColors.accentBlue,
                            isActive: route == '/team-dashboard',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/team-dashboard');
                            },
                          ),
                        if (showMeetings)
                          DrawerTile(
                            index: index++,
                            icon: Icons.videocam_rounded,
                            title: 'Meetings',
                            accent: HomeDashColors.accentBlue,
                            isActive: route == '/meetings' ||
                                route == '/meetings/detail',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/meetings');
                            },
                          ),
                        if (showMeetings &&
                            ref.watch(canViewMeetingRecordingsProvider))
                          DrawerTile(
                            index: index++,
                            icon: Icons.video_library_rounded,
                            title: 'Recordings',
                            accent: HomeDashColors.accentBlue,
                            isActive: route == '/meetings/recordings',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(
                                context,
                                '/meetings/recordings',
                              );
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    _menuGroup(
                      children: [
                        if (hasAnyKraPermission)
                          _buildExpandable(
                            index: index++,
                            title: 'KRA / KPI',
                            icon: Icons.track_changes_rounded,
                            accent: HomeDashColors.accentBlue,
                            expanded: _isKraExpanded,
                            isActive: route == '/kra',
                            onTap: () => setState(
                              () => _isKraExpanded = !_isKraExpanded,
                            ),
                            subItems: [
                              if (canManageKra)
                                _kraSubItem(
                                  'Create KRA',
                                  KraRouteArgs.createKra,
                                ),
                              if (canViewMyKra)
                                _kraSubItem('My KRA', KraRouteArgs.myRating),
                              if (canViewTeamKra || canManageKra)
                                _kraSubItem(
                                  'Team Rating',
                                  KraRouteArgs.teamRating,
                                ),
                              if (canViewDepartmentKra || canManageKra)
                                _kraSubItem(
                                  'Department Rating',
                                  KraRouteArgs.departmentRating,
                                ),
                              if (canViewAllKra)
                                _kraSubItem(
                                  'All Ratings',
                                  KraRouteArgs.allRatings,
                                ),
                              if (canManageKra)
                                _kraSubItem('KRA Setup', KraRouteArgs.setup),
                            ],
                          ),
                        _buildExpandable(
                          index: index++,
                          title: 'Expenses',
                          icon: Icons.receipt_long_rounded,
                          accent: HomeDashColors.accentBlue,
                          expanded: _isExpenseExpanded,
                          isActive: route == '/expenses/my' ||
                              route == '/expenses-dashboard',
                          onTap: () => setState(
                            () => _isExpenseExpanded = !_isExpenseExpanded,
                          ),
                          subItems: [
                            _subItem(
                              'My Expenses',
                              '/expenses/my',
                              Icons.payments_rounded,
                            ),
                            if (isExpenseManager ||
                                isExpenseHod ||
                                isAccounts)
                              _subItem(
                                'Expenses Dashboard',
                                '/expenses-dashboard',
                                Icons.dashboard_customize_rounded,
                              ),
                          ],
                        ),
                        DrawerTile(
                          index: index++,
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'Payslip',
                          accent: HomeDashColors.accentBlue,
                          isActive: route == '/payslip',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/payslip');
                          },
                        ),
                        DrawerTile(
                          index: index++,
                          icon: Icons.verified_user_rounded,
                          title: 'Policies',
                          accent: HomeDashColors.accentBlue,
                          isActive: route == '/policies',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/policies');
                          },
                        ),
                        _buildExpandable(
                          index: index++,
                          title: 'Resignation',
                          icon: Icons.work_off_rounded,
                          accent: HomeDashColors.accentBlue,
                          expanded: _isResignationExpanded,
                          isActive: route == '/resignation/my' ||
                              route == '/resignation-dashboard',
                          onTap: () => setState(
                            () => _isResignationExpanded =
                                !_isResignationExpanded,
                          ),
                          subItems: [
                            _subItem(
                              'My Resignation',
                              '/resignation/my',
                              Icons.person_off_rounded,
                            ),
                            if (isResignationManager ||
                                isResignationHod ||
                                isResignationHr)
                              _subItem(
                                'Resignation Dashboard',
                                '/resignation-dashboard',
                                Icons.assignment_rounded,
                              ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    _menuGroup(
                      children: [
                        DrawerTile(
                          index: index++,
                          icon: Icons.settings_rounded,
                          title: 'Settings',
                          accent: HomeDashColors.accentBlue,
                          isActive: route == '/settings',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/settings');
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    _buildHelpCard(),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
                ),
              ),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFBE123C),
                  backgroundColor: const Color(0xFFF8FAFC),
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true || !mounted) return;
                  invalidateAllUserScopedData(ref);
                  await ref.read(authProvider.notifier).logout();
                },
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuGroup({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  String _titleCase(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return value;
    return parts
        .map((p) {
          if (p.isEmpty) return p;
          return p[0].toUpperCase() + p.substring(1).toLowerCase();
        })
        .join(' ');
  }

  String _designationLabel(dynamic raw) {
    if (raw == null) return 'Employee';
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is Map && raw['name'] != null) {
      final name = raw['name'].toString().trim();
      if (name.isNotEmpty) return name;
    }
    return 'Employee';
  }

  Widget _buildProfileHeader({
    required String name,
    required String designation,
    required String? empCode,
    required String? imageUrl,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/profile');
        },
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage:
                      imageUrl != null ? NetworkImage(imageUrl) : null,
                  child: imageUrl == null
                      ? Text(
                          _initials(name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            designation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: Color(0xFF93C5FD),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (empCode != null)
                          _headerChip(Icons.badge_outlined, empCode),
                        _headerChip(
                          Icons.arrow_forward_rounded,
                          'View profile',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fade().slideY(begin: -.08);
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/policies');
        },
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: HomeDashColors.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need Help?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: HomeDashColors.title,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Policies & HR support resources',
                      style: TextStyle(
                        fontSize: 12,
                        color: HomeDashColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: HomeDashColors.muted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _buildExpandable({
    required int index,
    required String title,
    required IconData icon,
    required Color accent,
    required bool expanded,
    bool isActive = false,
    required VoidCallback onTap,
    required List<Widget> subItems,
  }) {
    return Column(
      children: [
        DrawerTile(
          index: index,
          icon: icon,
          title: title,
          accent: accent,
          isActive: isActive || expanded,
          showChevron: false,
          onTap: onTap,
          trailing: AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 220),
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: isActive || expanded
                    ? accent
                    : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: expanded
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 0, 8, 6),
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(children: subItems),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _goToKra(KraRouteArgs args) {
    final isAlreadyKra = ModalRoute.of(context)?.settings.name == '/kra';
    Navigator.pop(context);
    if (isAlreadyKra) {
      Navigator.pushReplacementNamed(context, '/kra', arguments: args);
    } else {
      Navigator.pushNamed(context, '/kra', arguments: args);
    }
  }

  Widget _kraSubItem(String title, KraRouteArgs args) {
    return _SubNavTile(
      title: title,
      icon: Icons.circle,
      accent: HomeDashColors.accentBlue,
      isActive: false,
      onTap: () => _goToKra(args),
    );
  }

  Widget _subItem(String title, String routeName, IconData icon) {
    final isActive = ModalRoute.of(context)?.settings.name == routeName;
    return _SubNavTile(
      title: title,
      icon: icon,
      accent: HomeDashColors.accentBlue,
      isActive: isActive,
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, routeName);
      },
    );
  }
}

class _SubNavTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final bool isActive;
  final VoidCallback onTap;

  const _SubNavTile({
    required this.title,
    required this.icon,
    required this.accent,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive ? accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive ? accent : HomeDashColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isActive ? accent : HomeDashColors.title,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: HomeDashColors.muted.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
