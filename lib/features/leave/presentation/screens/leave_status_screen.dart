import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/shared/widgets/app_bar.dart';
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final leaveAsync = ref.watch(leaveStatusProvider);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      drawer: const AppDrawer(),
      appBar: const AppAppBar(title: "Leaves status", showBack: false),

      body: leaveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (leaves) => LeaveStatusList(
          leaves: leaves,

          /// 👇 PASS expandLeaveId to list
          expandLeaveId: widget.expandLeaveId,
          onRefresh: () => ref.read(leaveStatusProvider.notifier).refresh(),
          onRevoke: (id, dates) =>
              ref.read(leaveStatusProvider.notifier).revokeLeave(id, dates),
        ),
      ),
    );
  }
}
