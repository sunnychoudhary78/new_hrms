import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LeaveApproveAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const LeaveApproveAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return AppBar(
      elevation: 0,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      title: const Text(
        "Leave Requests",
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      centerTitle: isIOS,
    );
  }
}
