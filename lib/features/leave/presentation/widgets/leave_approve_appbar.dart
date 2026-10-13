import 'package:flutter/material.dart';
import 'package:lms/shared/widgets/app_bar.dart';

class LeaveApproveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LeaveApproveAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return const AppAppBar(title: "Leave Requests", showBack: false);
  }
}
