import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/providers/my_corrections_provider.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/widgets/status_filter_pills.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/shared/widgets/app_bar.dart';

import '../widgets/my_correction_card.dart';

class MyCorrectionsScreen extends ConsumerWidget {
  const MyCorrectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    final stateAsync = ref.watch(myCorrectionsProvider);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(title: "My Correction Requests"),
      drawer: AppDrawer(),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (e, _) => Center(child: Text(e.toString())),

        data: (state) {
          final requests = state.requests;

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(myCorrectionsProvider.notifier).fetchCorrections();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                /// ALWAYS SHOW FILTER PILLS
                StatusFilterPills(
                  selected: state.statusFilter,
                  onChanged: (status) {
                    ref
                        .read(myCorrectionsProvider.notifier)
                        .changeStatus(status);
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                /// EMPTY STATE
                if (requests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(
                        "No correction requests found",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                /// LIST
                if (requests.isNotEmpty)
                  ...requests.map(
                    (req) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MyCorrectionCard(
                        request: req,
                        autoExpand: state.expandRequestId == req.id,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
