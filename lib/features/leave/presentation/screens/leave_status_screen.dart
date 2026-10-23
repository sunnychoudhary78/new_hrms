import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';
import '../providers/leave_status_provider.dart';
import '../widgets/leave_status_list.dart';

class LeaveStatusScreen extends ConsumerStatefulWidget {
  final String? expandLeaveId;
  const LeaveStatusScreen({super.key, this.expandLeaveId});

  @override
  ConsumerState<LeaveStatusScreen> createState() => _LeaveStatusScreenState();
}

class _LeaveStatusScreenState extends ConsumerState<LeaveStatusScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.invalidate(leaveStatusProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final leaveAsync = ref.watch(leaveStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: const AppDrawer(),
      appBar: const AppAppBar(title: "Leave Status", showBack: false),
      body: leaveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (leaves) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: AppHeroBanner(
                icon: Icons.event_available_outlined,
                title: "Your requests",
                message:
                    "Track pending, approved, and closed leave applications.",
              ),
            ),
            Expanded(
              child: LeaveStatusList(
                leaves: leaves,
                expandLeaveId: widget.expandLeaveId,
                onRefresh: () =>
                    ref.read(leaveStatusProvider.notifier).refresh(),
                onRevoke: (id, _) async {
                  await ref.read(leaveStatusProvider.notifier).revokeLeave(id);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
