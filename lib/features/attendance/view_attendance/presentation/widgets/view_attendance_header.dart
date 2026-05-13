import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';

class ViewAttendanceHeader extends ConsumerWidget {
  const ViewAttendanceHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final headerRadius = BorderRadius.circular(isIOS ? 18 : 22);
    final blur = isIOS ? 10.0 : 16.0;
    final shadowAlpha = isIOS ? 0.12 : 0.2;

    final auth = ref.watch(authProvider);

    final profile = auth.profile;
    final user = auth.authUser;

    final name = profile?.associatesName ?? user?.name ?? "Employee";
    final empId = profile?.payrollCode ?? "--";
    final profileUrl = auth.profileUrl;

    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: headerRadius,
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primaryContainer],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: shadowAlpha),
            blurRadius: blur,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: scheme.surface,
            backgroundImage: profileUrl.isNotEmpty
                ? NetworkImage(profileUrl)
                : const AssetImage('assets/images/profile.jpg')
                      as ImageProvider,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back,",
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onPrimary.withOpacity(.8),
                  ),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Employee ID · $empId",
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onPrimary.withOpacity(.8),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${now.day.toString().padLeft(2, '0')}/"
                "${now.month.toString().padLeft(2, '0')}/"
                "${now.year}",
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][now.weekday %
                    7],
                style: TextStyle(color: scheme.onPrimary.withOpacity(.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
