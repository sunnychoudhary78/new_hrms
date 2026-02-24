import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lms/app/app_root.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/home/presentation/widgets/drawer_item_tile.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer>
    with TickerProviderStateMixin {
  bool _isLeaveExpanded = false;
  bool _isAttendanceExpanded = false;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name;
    final authState = ref.watch(authProvider);
    final profile = authState.profile;
    final permissions = authState.permissions;
    final companyLogo = authState.companyLogoUrl;
    print("🏢 Company Logo URL: $companyLogo");

    final bool hasApprovePermission = permissions.contains(
      'leave.request.approve',
    );

    final name = profile?.associatesName ?? "User";
    final empId = profile?.payrollCode ?? "EMP0001";
    final profileImg = authState.profileUrl;

    final scheme = Theme.of(context).colorScheme;

    int index = 0;

    return Drawer(
      backgroundColor: scheme.surface,
      elevation: 12,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            /// SCROLLABLE CONTENT
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeader(name, empId, profileImg, companyLogo),

                    const SizedBox(height: 10),

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

                    if (hasApprovePermission)
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
                        if (hasApprovePermission)
                          _subItem("Leave Approve/Reject", "/leave-approve"),
                      ],
                    ),

                    DrawerTile(
                      index: index++,
                      icon: Icons.lock_outline_rounded,
                      title: "Change Password",
                      isActive: route == "/change-password",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, "/change-password");
                      },
                    ),

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
                        if (hasApprovePermission)
                          _subItem(
                            "Attendance Correction",
                            "/correct-attendance",
                          ),
                      ],
                    ),

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

            /// LOGOUT
            Divider(color: scheme.outlineVariant),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              child: DrawerTile(
                index: index++,
                icon: Icons.logout_rounded,
                title: "Logout",
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AppRoot()),
                    (_) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    String name,
    String empId,
    String img,
    String companyLogo,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color startColor = isDark ? const Color(0xFF1E1E2E) : scheme.primary;

    final Color endColor = isDark
        ? const Color(0xFF2A2A40)
        : scheme.primaryContainer;

    final textColor = isDark ? Colors.white : scheme.onPrimary;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [startColor, endColor],
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(.6),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🏢 COMPANY LOGO
          if (companyLogo.isNotEmpty)
            Center(
              child: Container(
                height: 50,
                margin: const EdgeInsets.only(bottom: 14),
                child: Image.network(
                  companyLogo,
                  fit: BoxFit.contain,

                  /// prevents crash if logo missing
                  errorBuilder: (_, __, ___) => const SizedBox(),

                  /// loading indicator
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                ),
              ),
            ),

          /// USER INFO ROW
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundImage: img.isNotEmpty
                    ? NetworkImage(img)
                    : const AssetImage('assets/images/profile.jpg')
                          as ImageProvider,
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      empId,
                      style: TextStyle(
                        color: textColor.withOpacity(.85),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade().slideY(begin: -.15);
  }

  Widget _buildExpandable({
    required int index,
    required String title,
    required IconData icon,
    required bool expanded,
    required VoidCallback onTap,
    required List<Widget> subItems,
  }) {
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
            child: const Icon(Icons.keyboard_arrow_down),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: expanded
              ? Column(
                  children: subItems,
                ).animate().fade(duration: 200.ms).slideY(begin: -.1)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _subItem(String title, String route) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 14, top: 4, bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, route);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14, color: scheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
