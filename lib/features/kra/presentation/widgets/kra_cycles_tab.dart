import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/kra/presentation/providers/kra_provider.dart';
import 'package:lms/features/kra/presentation/widgets/kra_ui_widgets.dart';

class KraCyclesTab extends ConsumerStatefulWidget {
  const KraCyclesTab({super.key});

  @override
  ConsumerState<KraCyclesTab> createState() => _KraCyclesTabState();
}

class _KraCyclesTabState extends ConsumerState<KraCyclesTab> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final cyclesAsync = ref.watch(kraCyclesProvider);
    final state = ref.watch(kraActionProvider);

    return Column(
      children: [
        KraInfoBanner(
          icon: Icons.event_available_rounded,
          title: 'Review Cycles',
          subtitle: 'Start monthly KRA reviews and track active cycles.',
          trailing: FilledButton(
            onPressed: state.isLoading ? null : _initiate,
            child: state.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Start'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _month,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: List.generate(
                    12,
                    (i) =>
                        DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                  ),
                  onChanged: (v) => setState(() => _month = v ?? _month),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: _year.toString(),
                  decoration: const InputDecoration(labelText: 'Year'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _year = int.tryParse(v) ?? _year,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(kraCyclesProvider),
            child: cyclesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  KraErrorList(message: 'Unable to load cycles.\n$e'),
              data: (cycles) {
                if (cycles.isEmpty) {
                  return const KraEmptyList(text: 'No review cycles yet');
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (_, i) {
                    final cycle = cycles[i];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLow,
                      leading: const Icon(Icons.event_available),
                      title: Text(cycle.label),
                      subtitle: Text(cycle.status),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: cycles.length,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _initiate() async {
    await ref
        .read(kraActionProvider.notifier)
        .initiateCycle(month: _month, year: _year);
    final state = ref.read(kraActionProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.hasError ? 'Error: ${state.error}' : 'Review cycle started',
        ),
      ),
    );
  }
}
