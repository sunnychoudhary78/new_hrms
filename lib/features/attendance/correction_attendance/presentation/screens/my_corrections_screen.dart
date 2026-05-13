import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/providers/my_corrections_provider.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/shared/widgets/app_bar.dart';

import '../widgets/my_correction_card.dart';
import '../widgets/section_header.dart';

class MyCorrectionsScreen extends ConsumerStatefulWidget {
  const MyCorrectionsScreen({super.key});

  @override
  ConsumerState<MyCorrectionsScreen> createState() =>
      _MyCorrectionsScreenState();
}

class _MyCorrectionsScreenState extends ConsumerState<MyCorrectionsScreen> {
  @override
  void initState() {
    super.initState();

    /// Always fetch latest corrections when screen opens
    Future.microtask(() {
      ref.read(myCorrectionsProvider.notifier).fetchCorrections();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stateAsync = ref.watch(myCorrectionsProvider);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(title: "My Correction Requests"),
      drawer: const AppDrawer(),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(isIOS ? 12 : 14),
            ),
            child: Text(
              "Unable to load correction requests.\n$e",
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ),
        data: (state) {
          final requests = state.requests;

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(myCorrectionsProvider.notifier).fetchCorrections();
            },
            child: ListView(
              physics: isIOS
                  ? const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    )
                  : const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isIOS ? 14 : 18),
                    gradient: LinearGradient(
                      colors: [
                        scheme.primaryContainer,
                        scheme.secondaryContainer,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: scheme.primary,
                        child: Icon(
                          Icons.fact_check_outlined,
                          color: scheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Track all your correction requests and review their status updates.",
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: SectionHeader(
                        title: "Filter by status",
                        icon: Icons.filter_alt_rounded,
                      ),
                    ),

                    PopupMenuButton<String>(
                      tooltip: "Filter: ${state.statusFilter}",
                      onSelected: (value) {
                        ref
                            .read(myCorrectionsProvider.notifier)
                            .changeStatus(value);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: "PENDING", child: Text("Pending")),
                        PopupMenuItem(
                          value: "APPROVED",
                          child: Text("Approved"),
                        ),
                        PopupMenuItem(
                          value: "REJECTED",
                          child: Text("Rejected"),
                        ),
                        PopupMenuItem(value: "ALL", child: Text("All")),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_list_rounded, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              state.statusFilter,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                if (requests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(isIOS ? 12 : 16),
                        color: scheme.surfaceContainerLow,
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_rounded,
                            size: 44,
                            color: scheme.primary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "No correction requests found",
                            style: TextStyle(
                              fontSize: 15,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

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
