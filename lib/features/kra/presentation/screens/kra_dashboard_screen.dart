import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/kra/presentation/kra_route_args.dart';
import 'package:lms/features/kra/presentation/providers/kra_provider.dart';
import 'package:lms/features/kra/presentation/widgets/kra_cycles_tab.dart';
import 'package:lms/features/kra/presentation/widgets/kra_management_tab.dart';
import 'package:lms/features/kra/presentation/widgets/kra_review_tab.dart';
import 'package:lms/features/kra/presentation/widgets/kra_ui_widgets.dart';

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
      for (final mode in modes) _KraTab(mode.label, KraReviewTab(mode: mode)),
      if (modes.contains(KraReviewMode.self))
        const _KraTab('My KRAs', MyKrasList()),
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
        if (mounted) showKraCreateFormSheet(context);
      });
    }

    if (tabs.isEmpty) {
      return const Scaffold(
        appBar: _KraAppBar(),
        body: KraEmptyList(text: 'No KRA access available for this account'),
      );
    }

    return DefaultTabController(
      key: ValueKey('kra-tabs-${tabs.length}-$initialIndex'),
      length: tabs.length,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: _KraAppBar(
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final tab in tabs) Tab(text: tab.label)],
          ),
        ),
        body: Column(
          children: [
            const _ActiveCycleBanner(),
            Expanded(
              child: TabBarView(children: [for (final tab in tabs) tab.child]),
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

class _KraAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget? bottom;

  const _KraAppBar({this.bottom});

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('KRA / KPI'), bottom: bottom);
  }
}

class _ActiveCycleBanner extends ConsumerWidget {
  const _ActiveCycleBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycleAsync = ref.watch(kraActiveCycleProvider);
    final scheme = Theme.of(context).colorScheme;

    return cycleAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, __) => const SizedBox.shrink(),
      data: (cycle) => KraInfoBanner(
        icon: Icons.track_changes,
        title: cycle == null
            ? 'No active KRA review cycle'
            : 'Active review cycle: ${cycle.label}',
        subtitle: cycle == null
            ? 'Start a cycle from the Cycles tab when available.'
            : cycle.status,
        trailing: Icon(Icons.insights_rounded, color: scheme.primary),
      ),
    );
  }
}
