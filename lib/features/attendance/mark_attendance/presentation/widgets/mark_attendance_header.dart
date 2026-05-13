import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';

class MarkAttendanceHeader extends ConsumerWidget {
  final String dayName;

  const MarkAttendanceHeader({super.key, required this.dayName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    final authState = ref.watch(authProvider);
    final profile = authState.profile;
    final profileUrl = authState.profileUrl;

    final now = DateTime.now();

    final name = profile?.associatesName ?? "--";
    final empId = profile?.payrollCode ?? "--";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(isIOS ? 16 : 20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
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
                  "Welcome,",
                  style: TextStyle(color: scheme.onPrimary.withOpacity(.8)),
                ),
                Text(
                  name,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "Employee ID: $empId",
                  style: TextStyle(color: scheme.onPrimary.withOpacity(.8)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${now.day}/${now.month}/${now.year}",
                style: TextStyle(color: scheme.onPrimary),
              ),
              Text(
                dayName,
                style: TextStyle(color: scheme.onPrimary.withOpacity(.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
