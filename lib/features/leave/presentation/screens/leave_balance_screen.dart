import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/features/leave/presentation/widgets/leave_balance_list.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import '../providers/leave_balance_provider.dart';
import '../widgets/leave_pie_chart.dart';

class LeaveBalanceScreen extends ConsumerWidget {
  const LeaveBalanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    ref.watch(authProvider); // 👈 important

    final leaveAsync = ref.watch(leaveBalanceProvider);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(
        title: "Leave Balance",
        showBack: false, // 👈 Root screen → no back button
      ),
      drawer: AppDrawer(),
      body: leaveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (leaves) {
          if (leaves.isEmpty) {
            return const Center(child: Text("No leave data found"));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Overview",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                LeavePieChart(leaves: leaves), // ✅ CORRECT

                const SizedBox(height: 28),

                const Text(
                  "Leave Details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                LeaveBalanceList(leaves: leaves), // ✅ CORRECT
              ],
            ),
          );
        },
      ),
    );
  }
}
