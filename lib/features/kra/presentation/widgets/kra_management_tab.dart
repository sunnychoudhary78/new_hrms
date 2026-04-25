import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/kra/data/models/kra_model.dart';
import 'package:lms/features/kra/presentation/providers/kra_provider.dart';
import 'package:lms/features/kra/presentation/widgets/kra_ui_widgets.dart';

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
                onPressed: () => _openForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Create KPI'),
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
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Create KPI'),
          ),
        ),
      ],
    );
  }

  void _openForm(BuildContext context, {KraModel? kra}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => KraFormSheet(kra: kra),
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
      itemBuilder: (_, i) => _KraCard(kra: items[i]),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: items.length,
    );
  }
}

class MyKrasList extends ConsumerWidget {
  const MyKrasList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final krasAsync = ref.watch(myKrasProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myKrasProvider),
      child: krasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => KraErrorList(message: 'Unable to load KRAs.\n$e'),
        data: (items) =>
            _ReadonlyKraList(items: items, emptyText: 'No KRAs assigned yet'),
      ),
    );
  }
}

class _ReadonlyKraList extends StatelessWidget {
  final List<KraModel> items;
  final String emptyText;

  const _ReadonlyKraList({required this.items, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return KraEmptyList(text: emptyText);
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemBuilder: (_, i) => _KraCard(kra: items[i], canManage: false),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
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
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => KraFormSheet(kra: kra),
                      );
                      return;
                    }
                    final ok = await _confirmDelete(context);
                    if (ok == true) {
                      await ref
                          .read(kraActionProvider.notifier)
                          .deleteKra(kra.id);
                      final state = ref.read(kraActionProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              state.hasError
                                  ? 'Error: ${state.error}'
                                  : 'KRA deleted',
                            ),
                          ),
                        );
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
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete KRA?'),
        content: const Text('This KRA and its KPI targets will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.kra == null ? 'Create KRA & KPI' : 'Edit KRA',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => setState(() => _kpis.add(_KpiDraft())),
                    icon: const Icon(Icons.add),
                    label: const Text('Create KPI'),
                  ),
                ],
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
              ),
              const SizedBox(height: 16),
              _KpiSection(
                kpis: _kpis,
                onAdd: () => setState(() => _kpis.add(_KpiDraft())),
                onRemove: (index) => setState(() {
                  final removed = _kpis.removeAt(index);
                  removed.dispose();
                }),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
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
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('KRA name required');
      return;
    }

    final kpis = _kpis
        .map((e) => e.toKpi())
        .where((e) => e.name.trim().isNotEmpty)
        .toList();
    if (kpis.isEmpty) {
      _snack('Create at least one KPI');
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
      _snack('Error: ${state.error}');
      return;
    }
    Navigator.pop(context);
    _snack('KRA saved');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _KraDetailsForm extends StatelessWidget {
  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController departmentId;
  final String? employeeId;
  final AsyncValue<List<KraPerson>> membersAsync;
  final ValueChanged<String?> onEmployeeChanged;

  const _KraDetailsForm({
    required this.name,
    required this.description,
    required this.departmentId,
    required this.employeeId,
    required this.membersAsync,
    required this.onEmployeeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'KRA name *'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: description,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 10),
        membersAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
          data: (members) {
            final selectedId = members.any((member) => member.id == employeeId)
                ? employeeId
                : null;
            return DropdownButtonFormField<String>(
              initialValue: selectedId,
              decoration: const InputDecoration(labelText: 'Employee'),
              items: [
                for (final member in members)
                  DropdownMenuItem(value: member.id, child: Text(member.name)),
              ],
              onChanged: onEmployeeChanged,
            );
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: departmentId,
          decoration: const InputDecoration(
            labelText: 'Department ID (optional)',
          ),
        ),
      ],
    );
  }
}

class _KpiSection extends StatelessWidget {
  final List<_KpiDraft> kpis;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _KpiSection({
    required this.kpis,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'KPI Targets',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Create KPI'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final entry in kpis.asMap().entries)
            _KpiDraftTile(
              draft: entry.value,
              onRemove: kpis.length == 1 ? null : () => onRemove(entry.key),
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

  const _KpiDraftTile({required this.draft, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
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
                    decoration: const InputDecoration(labelText: 'KPI name *'),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: draft.description,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: draft.weightage,
              decoration: const InputDecoration(labelText: 'Weightage *'),
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
}

/// Opens the Create KRA & KPI bottom sheet (e.g. from the drawer “Create KRA” entry).
void showKraCreateFormSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const KraFormSheet(),
  );
}
