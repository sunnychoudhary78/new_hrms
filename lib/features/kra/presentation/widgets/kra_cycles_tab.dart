import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';
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
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final fieldRadius = BorderRadius.circular(isIOS ? 12 : AppRadius.md);

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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: PremiumCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _month,
                    decoration: InputDecoration(
                      labelText: 'Month',
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: fieldRadius,
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: fieldRadius,
                        borderSide: const BorderSide(color: AppColors.border),
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
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: fieldRadius,
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: fieldRadius,
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _year = int.tryParse(v) ?? _year,
                  ),
                ),
              ],
            ),
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
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemBuilder: (_, i) {
                    final cycle = cycles[i];
                    return PremiumCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.heroStart.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Icon(
                              Icons.event_available,
                              color: AppColors.heroStart,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cycle.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.title,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cycle.status,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          KraStatusChip(status: cycle.status),
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
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
