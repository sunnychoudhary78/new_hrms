import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/features/kra/data/models/kra_model.dart';
import 'package:lms/features/kra/presentation/providers/kra_provider.dart';
import 'package:lms/features/kra/presentation/widgets/kra_ui_widgets.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';

/// One [DropdownMenuItem] value per id; skips blank ids so [DropdownButtonFormField]
/// never hits Flutter's "exactly one item with value" assert (duplicate/empty ids).
List<KraPerson> _dedupeTeamMembers(List<KraPerson> members) {
  final seen = <String>{};
  final out = <KraPerson>[];
  for (final m in members) {
    final id = m.id.trim();
    if (id.isEmpty) continue;
    if (seen.add(id)) out.add(m);
  }
  return out;
}

class KraManagementTab extends ConsumerWidget {
  const KraManagementTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final krasAsync = ref.watch(managedKrasProvider);

    return Stack(
      children: [
        Column(
          children: [
            KraInfoBanner(
              icon: Icons.add_task_rounded,
              title: 'KRA Setup',
              subtitle: 'Create KRA records and add KPI targets for employees.',
              trailing: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      defaultTargetPlatform == TargetPlatform.iOS ? 12 : 20,
                    ),
                  ),
                ),
                onPressed: () => openKraFormBottomSheet(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Create KRA'),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(managedKrasProvider),
                child: krasAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      KraErrorList(message: 'Unable to load KRAs.\n$e'),
                  data: (items) =>
                      _KraList(items: items, emptyText: 'No KRAs created yet'),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 18,
          child: FloatingActionButton.extended(
            onPressed: () => openKraFormBottomSheet(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Create KRA'),
          ),
        ),
      ],
    );
  }
}

class _KraList extends StatelessWidget {
  final List<KraModel> items;
  final String emptyText;

  const _KraList({required this.items, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return KraEmptyList(text: emptyText);

    return ListView.separated(
      physics: defaultTargetPlatform == TargetPlatform.iOS
          ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())
          : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
      itemBuilder: (_, i) => _KraCard(kra: items[i], canManage: true),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: items.length,
    );
  }
}

class _KraCard extends ConsumerWidget {
  final KraModel kra;
  final bool canManage;

  const _KraCard({required this.kra, this.canManage = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final cardRadius = BorderRadius.circular(isIOS ? 12 : 16);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: cardRadius,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kra.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (kra.employee != null)
                      Text(
                        kra.employee!.name,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      openKraFormBottomSheet(context, ref, kra: kra);
                      return;
                    }
                    final ok = await _confirmDelete(context);
                    if (ok == true) {
                      await ref
                          .read(kraActionProvider.notifier)
                          .deleteKra(kra.id);
                      final state = ref.read(kraActionProvider);
                      if (context.mounted) {
                        final o = ref.read(globalLoadingProvider.notifier);
                        if (state.hasError) {
                          o.showError('${state.error}');
                        } else {
                          o.showSuccess('KRA deleted');
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
          if (kra.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(kra.description),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              KraMetaPill(
                icon: Icons.account_tree_outlined,
                text:
                    kra.department?.name ??
                    'Department ${kra.departmentId ?? '-'}',
              ),
              KraMetaPill(
                icon: Icons.checklist_rtl,
                text: '${kra.kpis.length} KPI(s)',
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final kpi in kra.kpis)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(kpi.name)),
                  Text(
                    '${kpi.weightage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isIOS ? 14 : 24),
        ),
        title: const Text('Delete KRA?'),
        content: const Text('This KRA and its KPI targets will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isIOS ? 12 : 20),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class KraFormSheet extends ConsumerStatefulWidget {
  final KraModel? kra;

  const KraFormSheet({super.key, this.kra});

  @override
  ConsumerState<KraFormSheet> createState() => _KraFormSheetState();
}

class _KraFormSheetState extends ConsumerState<KraFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _departmentId;
  String? _employeeId;
  final List<_KpiDraft> _kpis = [];

  @override
  void initState() {
    super.initState();
    final kra = widget.kra;
    _name = TextEditingController(text: kra?.name ?? '');
    _description = TextEditingController(text: kra?.description ?? '');
    _departmentId = TextEditingController(text: kra?.departmentId ?? '');
    _employeeId = kra?.employeeId;
    if (kra == null || kra.kpis.isEmpty) {
      _kpis.add(_KpiDraft());
    } else {
      _kpis.addAll(kra.kpis.map(_KpiDraft.fromKpi));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _departmentId.dispose();
    for (final kpi in _kpis) {
      kpi.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(kraTeamMembersProvider);
    final action = ref.watch(kraActionProvider);
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final fieldRadius = BorderRadius.circular(isIOS ? 12 : 16);
    final saveShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(isIOS ? 12 : 20),
    );

    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: isIOS
                ? const BouncingScrollPhysics()
                : const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isIOS)
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                PremiumSectionTitle(
                  title: widget.kra == null ? 'Create KRA & KPI' : 'Edit KRA',
                  subtitle:
                      'Assign an employee, define KPI targets, and keep total weightage at 100%.',
                  trailing: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isIOS ? 12 : 20),
                      ),
                    ),
                    onPressed: () => setState(() => _kpis.add(_KpiDraft())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add KPI'),
                  ),
                ),
                const SizedBox(height: 12),
                _KraDetailsForm(
                  name: _name,
                  description: _description,
                  departmentId: _departmentId,
                  employeeId: _employeeId,
                  membersAsync: membersAsync,
                  onEmployeeChanged: (value) =>
                      setState(() => _employeeId = value),
                  fieldBorderRadius: fieldRadius,
                ),
                const SizedBox(height: 16),
                _KpiSection(
                  kpis: _kpis,
                  onChanged: () => setState(() {}),
                  onAdd: () => setState(() => _kpis.add(_KpiDraft())),
                  onRemove: (index) => setState(() {
                    final removed = _kpis.removeAt(index);
                    removed.dispose();
                  }),
                  fieldBorderRadius: fieldRadius,
                  isIOS: isIOS,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(shape: saveShape),
                    onPressed: action.isLoading ? null : _save,
                    child: action.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save KRA'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final o = ref.read(globalLoadingProvider.notifier);
    final name = _name.text.trim();
    if (name.isEmpty) {
      o.showError('KRA name required');
      return;
    }

    final kpis = _kpis
        .map((e) => e.toKpi())
        .where((e) => e.name.trim().isNotEmpty)
        .toList();
    if (kpis.isEmpty) {
      o.showError('Add at least one KPI with a name');
      return;
    }

    for (final k in kpis) {
      if (k.weightage <= 0) {
        o.showError('Each KPI must have weightage greater than 0');
        return;
      }
    }

    final sum = kpis.fold<double>(0, (a, b) => a + b.weightage);
    if ((sum - 100).abs() > 0.01) {
      o.showError(
        'KPI weightages must sum to exactly 100% (current total: '
        '${sum.toStringAsFixed(1)}%)',
      );
      return;
    }

    await ref
        .read(kraActionProvider.notifier)
        .saveKra(
          id: widget.kra?.id,
          name: name,
          description: _description.text,
          departmentId: _departmentId.text,
          employeeId: _employeeId,
          kpis: kpis,
        );
    final state = ref.read(kraActionProvider);
    if (!mounted) return;
    if (state.hasError) {
      o.showError('${state.error}');
      return;
    }
    Navigator.pop(context);
    o.showSuccess(widget.kra == null ? 'KRA created' : 'KRA updated');
  }
}

class _KraDetailsForm extends ConsumerWidget {
  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController departmentId;
  final String? employeeId;
  final AsyncValue<List<KraPerson>> membersAsync;
  final ValueChanged<String?> onEmployeeChanged;
  final BorderRadius fieldBorderRadius;

  const _KraDetailsForm({
    required this.name,
    required this.description,
    required this.departmentId,
    required this.employeeId,
    required this.membersAsync,
    required this.onEmployeeChanged,
    required this.fieldBorderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          TextField(
            controller: name,
            decoration: _inputDecoration(context, 'KRA name *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: description,
            minLines: 2,
            maxLines: 3,
            decoration: _inputDecoration(context, 'Description'),
          ),
          const SizedBox(height: 10),
          membersAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Could not load team members.',
                  style: TextStyle(color: scheme.error),
                ),
                const SizedBox(height: 4),
                Text(
                  '$e',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => ref.invalidate(kraTeamMembersProvider),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
            data: (members) {
              final unique = _dedupeTeamMembers(members);
              final selectedId = unique.any((member) => member.id == employeeId)
                  ? employeeId
                  : null;
              if (unique.isEmpty) {
                return InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Employee',
                    helperText:
                        'No direct reports returned. You can still save with department ID; assign employee when available.',
                  ),
                  child: Text(
                    'No team members',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                );
              }
              return DropdownButtonFormField<String>(
                key: ValueKey('kra-emp-${unique.length}-$employeeId'),
                initialValue: selectedId,
                decoration: _inputDecoration(
                  context,
                  'Employee',
                  helperText:
                      'Department can be left blank; it may be filled from employee on save.',
                ),
                items: [
                  for (final member in unique)
                    DropdownMenuItem(
                      value: member.id,
                      child: Text(member.name),
                    ),
                ],
                onChanged: onEmployeeChanged,
              );
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: departmentId,
            decoration: _inputDecoration(context, 'Department ID (optional)'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context,
    String label, {
    String? helperText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: fieldBorderRadius),
    );
  }
}

class _KpiSection extends StatelessWidget {
  final List<_KpiDraft> kpis;
  final VoidCallback onAdd;
  final VoidCallback onChanged;
  final ValueChanged<int> onRemove;
  final BorderRadius fieldBorderRadius;
  final bool isIOS;

  const _KpiSection({
    required this.kpis,
    required this.onAdd,
    required this.onChanged,
    required this.onRemove,
    required this.fieldBorderRadius,
    required this.isIOS,
  });

  double _namedWeightTotal() {
    double t = 0;
    for (final d in kpis) {
      if (d.name.text.trim().isEmpty) continue;
      t += double.tryParse(d.weightage.text.trim()) ?? 0;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = _namedWeightTotal();
    final ok = (total - 100).abs() <= 0.01;
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              const Text(
                'KPI targets',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isIOS ? 12 : 20),
                  ),
                ),
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add KPI'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Weightages must sum to 100% (named KPIs only). '
            'Current: ${total.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ok ? Colors.green.shade700 : scheme.error,
            ),
          ),
          const SizedBox(height: 10),
          for (final entry in kpis.asMap().entries)
            _KpiDraftTile(
              draft: entry.value,
              onFieldChanged: onChanged,
              onRemove: kpis.length == 1 ? null : () => onRemove(entry.key),
              fieldBorderRadius: fieldBorderRadius,
              isIOS: isIOS,
            ),
        ],
      ),
    );
  }
}

class _KpiDraft {
  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController weightage;

  _KpiDraft()
    : name = TextEditingController(),
      description = TextEditingController(),
      weightage = TextEditingController();

  _KpiDraft.fromKpi(KpiModel kpi)
    : name = TextEditingController(text: kpi.name),
      description = TextEditingController(text: kpi.description),
      weightage = TextEditingController(text: kpi.weightage.toStringAsFixed(0));

  KpiModel toKpi() {
    return KpiModel(
      id: '',
      name: name.text.trim(),
      description: description.text.trim(),
      weightage: double.tryParse(weightage.text.trim()) ?? 0,
    );
  }

  void dispose() {
    name.dispose();
    description.dispose();
    weightage.dispose();
  }
}

class _KpiDraftTile extends StatelessWidget {
  final _KpiDraft draft;
  final VoidCallback? onRemove;
  final VoidCallback onFieldChanged;
  final BorderRadius fieldBorderRadius;
  final bool isIOS;

  const _KpiDraftTile({
    required this.draft,
    required this.onFieldChanged,
    required this.fieldBorderRadius,
    required this.isIOS,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isIOS ? 12 : 18),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.name,
                    onChanged: (_) => onFieldChanged(),
                    decoration: _inputDecoration(context, 'KPI name *'),
                  ),
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    splashFactory: isIOS
                        ? NoSplash.splashFactory
                        : InkSplash.splashFactory,
                  ),
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: draft.description,
              onChanged: (_) => onFieldChanged(),
              decoration: _inputDecoration(context, 'Description'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: draft.weightage,
              onChanged: (_) => onFieldChanged(),
              decoration: _inputDecoration(
                context,
                'Weightage % *',
                helperText: 'Share of 100% across all named KPIs',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context,
    String label, {
    String? helperText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: fieldBorderRadius),
    );
  }
}

/// Opens the Create/Edit KRA & KPI bottom sheet. Resets [kraActionProvider] first so a
/// stuck “loading” from a prior cycle init / save does not break the form; uses
/// the root navigator so the sheet is not under the [TabBarView] overlay in a way
/// that can yield an empty (white) full-screen on some devices.
void openKraFormBottomSheet(
  BuildContext context,
  WidgetRef ref, {
  KraModel? kra,
}) {
  ref.read(kraActionProvider.notifier).resetActionState();
  final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: isIOS,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(isIOS ? 14 : 28),
      ),
    ),
    builder: (_) =>
        FractionallySizedBox(heightFactor: 0.92, child: KraFormSheet(kra: kra)),
  );
}

/// Opens the Create KRA & KPI bottom sheet (e.g. from the drawer “Create KRA” entry).
void showKraCreateFormSheet(BuildContext context, WidgetRef ref) {
  openKraFormBottomSheet(context, ref);
}
