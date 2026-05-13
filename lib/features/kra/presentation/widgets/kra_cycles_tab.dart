import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final fieldRadius = BorderRadius.circular(isIOS ? 12 : 16);
    final tileRadius = BorderRadius.circular(isIOS ? 12 : 18);

    return Column(
      children: [
        KraInfoBanner(
          icon: Icons.event_available_rounded,
          title: 'Review Cycles',
          subtitle: 'Start monthly KRA reviews and track active cycles.',
          trailing: FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isIOS ? 12 : 20),
              ),
            ),
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
                  decoration: InputDecoration(
                    labelText: 'Month',
                    filled: true,
                    fillColor: scheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: fieldRadius,
                    ),
                  ),
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
                  decoration: InputDecoration(
                    labelText: 'Year',
                    filled: true,
                    fillColor: scheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: fieldRadius,
                    ),
                  ),
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
                  physics: isIOS
                      ? const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        )
                      : const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (_, i) {
                    final cycle = cycles[i];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: tileRadius,
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      tileColor: scheme.surfaceContainerLow,
                      leading: Icon(
                        Icons.event_available,
                        color: scheme.primary,
                      ),
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
    final o = ref.read(globalLoadingProvider.notifier);
    if (state.hasError) {
      o.showError('${state.error}');
    } else {
      o.showSuccess('Review cycle started');
    }
  }
}
