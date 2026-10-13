import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/kra/presentation/kra_route_args.dart';
import 'package:lms/features/kra/presentation/providers/kra_provider.dart';
import 'package:lms/features/kra/presentation/widgets/kra_cycles_tab.dart';
import 'package:lms/features/kra/presentation/widgets/kra_management_tab.dart';
import 'package:lms/features/kra/presentation/widgets/kra_review_tab.dart';
import 'package:lms/features/kra/presentation/widgets/kra_ui_widgets.dart';
import 'package:lms/shared/widgets/app_bar.dart';

class KraDashboardScreen extends ConsumerStatefulWidget {
  const KraDashboardScreen({super.key});

  @override
  ConsumerState<KraDashboardScreen> createState() => _KraDashboardScreenState();
}

class _KraDashboardScreenState extends ConsumerState<KraDashboardScreen> {
  bool _openedCreateSheet = false;

  @override
  Widget build(BuildContext context) {
    final args = kraArgsFromRoute(ModalRoute.of(context)?.settings.arguments);
    final modes = ref.watch(kraVisibleReviewModesProvider);
    final canManage = ref.watch(canManageKraProvider);
    final tabs = [
      for (final mode in modes)
        _KraTab(
          mode.label,
          mode == KraReviewMode.self
              ? const KraMyKraUnifiedTab()
              : KraReviewTab(mode: mode),
        ),
      if (canManage) const _KraTab('KRA Setup', KraManagementTab()),
      if (canManage) const _KraTab('Cycles', KraCyclesTab()),
    ];

    final initialIndex = resolveKraInitialTabIndex(
      modes: modes,
      canManage: canManage,
      tabCount: tabs.length,
      target: args?.tab,
    );

    if (args != null &&
        args.openCreateForm &&
        canManage &&
        !_openedCreateSheet) {
      _openedCreateSheet = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showKraCreateFormSheet(context, ref);
      });
    }

    if (tabs.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: const AppAppBar(title: 'KRA / KPI'),
        body: const KraEmptyList(text: 'No KRA access available for this account'),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      key: ValueKey(
        'kra-tc-len${tabs.length}-m$canManage-t${args?.tab.name ?? 'none'}',
      ),
      length: tabs.length,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppAppBar(
          title: 'KRA / KPI',
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.heroStart,
            labelColor: AppColors.heroStart,
            unselectedLabelColor: AppColors.muted,
            dividerColor: scheme.outline.withValues(alpha: 0.12),
            tabs: [for (final tab in tabs) Tab(text: tab.label)],
          ),
        ),
        body: Column(
          children: [
            const _ActiveCycleBanner(),
            Expanded(
              child: TabBarView(
                physics: defaultTargetPlatform == TargetPlatform.iOS
                    ? const BouncingScrollPhysics()
                    : const ClampingScrollPhysics(),
                children: [for (final tab in tabs) tab.child],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KraTab {
  final String label;
  final Widget child;

  const _KraTab(this.label, this.child);
}

class _ActiveCycleBanner extends ConsumerWidget {
  const _ActiveCycleBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycleAsync = ref.watch(kraActiveCycleProvider);

    return cycleAsync.when(
      loading: () => const LinearProgressIndicator(
        minHeight: 2,
        color: AppColors.heroStart,
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (cycle) => KraInfoBanner(
        icon: Icons.track_changes,
        title: cycle == null
            ? 'No active KRA review cycle'
            : 'Active review cycle: ${cycle.label}',
        subtitle: cycle == null
            ? 'Start a cycle from the Cycles tab when available.'
            : cycle.status,
        trailing: Icon(
          Icons.insights_rounded,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
