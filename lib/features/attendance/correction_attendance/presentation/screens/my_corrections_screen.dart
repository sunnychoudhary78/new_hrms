import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/providers/my_corrections_provider.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';

import '../widgets/my_correction_card.dart';

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
    Future.microtask(() {
      ref.read(myCorrectionsProvider.notifier).fetchCorrections();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(myCorrectionsProvider);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppAppBar(title: 'My Correction Requests'),
      drawer: const AppDrawer(),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: appScreenPadding,
          child: AppSectionCard(
            child: Text(
              'Unable to load correction requests.\n$e',
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
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
              padding: appScreenPadding,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: AppColors.heroDecoration(radius: AppRadius.lg),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white24,
                        child: Icon(
                          Icons.fact_check_outlined,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Track all your correction requests and review their status updates.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Filter by status',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Filter: ${state.statusFilter}',
                      onSelected: (value) {
                        ref
                            .read(myCorrectionsProvider.notifier)
                            .changeStatus(value);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'PENDING', child: Text('Pending')),
                        PopupMenuItem(
                          value: 'APPROVED',
                          child: Text('Approved'),
                        ),
                        PopupMenuItem(
                          value: 'REJECTED',
                          child: Text('Rejected'),
                        ),
                        PopupMenuItem(value: 'ALL', child: Text('All')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.filter_list_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _prettyFilter(state.statusFilter),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.title,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (requests.isEmpty)
                  const AppSectionCard(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 40,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No correction requests found',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.title,
                          ),
                        ),
                      ],
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

  String _prettyFilter(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return 'Pending';
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      default:
        return 'All';
    }
  }
}
