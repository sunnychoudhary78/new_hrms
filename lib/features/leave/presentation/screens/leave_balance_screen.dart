import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/features/leave/presentation/screens/leave_apply_screen.dart';
import 'package:lms/features/leave/presentation/widgets/leave_balance_list.dart';
import 'package:lms/features/onboarding/data/day_one_route.dart';
import 'package:lms/features/onboarding/presentation/widgets/feature_tour_overlay.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import '../providers/leave_balance_provider.dart';
import '../widgets/leave_pie_chart.dart';

class LeaveBalanceScreen extends ConsumerStatefulWidget {
  const LeaveBalanceScreen({super.key});

  @override
  ConsumerState<LeaveBalanceScreen> createState() => _LeaveBalanceScreenState();
}

class _LeaveBalanceScreenState extends ConsumerState<LeaveBalanceScreen> {
  final GlobalKey _balanceKey = GlobalKey();
  final GlobalKey _applyKey = GlobalKey();
  bool _tourStarted = false;

  void _maybeStartTour() {
    if (_tourStarted || !mounted) return;
    final tour = tourIdFromArgs(ModalRoute.of(context)?.settings.arguments);
    if (tour != 'leave') return;
    _tourStarted = true;
    FeatureTourOverlay.maybeStart(
      context: context,
      tourId: tour,
      targets: {
        'leave-view-balance': _balanceKey,
        'leave-apply': _applyKey,
      },
    );
  }

  void _openApply() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeaveApplyScreen()),
    );
  }

  @override
  void dispose() {
    FeatureTourOverlay.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    ref.watch(authProvider);

    final leaveAsync = ref.watch(leaveBalanceProvider);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: "Leave Balance",
        showBack: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: KeyedSubtree(
              key: _applyKey,
              child: IconButton(
                tooltip: 'Apply Leave',
                onPressed: _openApply,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: leaveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (leaves) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
          final notifier = ref.read(leaveBalanceProvider.notifier);
          final scrollPhysics = defaultTargetPlatform == TargetPlatform.iOS
              ? const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                )
              : const AlwaysScrollableScrollPhysics();

          if (leaves.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
            return RefreshIndicator(
              onRefresh: notifier.refresh,
              child: ListView(
                physics: scrollPhysics,
                children: [
                  const SizedBox(height: 260),
                  Center(
                    child: KeyedSubtree(
                      key: _balanceKey,
                      child: const Text("No leave data found"),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: notifier.refresh,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: scrollPhysics,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyedSubtree(
                    key: _balanceKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Overview",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LeavePieChart(leaves: leaves),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    "Leave Details",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  LeaveBalanceList(leaves: leaves),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
