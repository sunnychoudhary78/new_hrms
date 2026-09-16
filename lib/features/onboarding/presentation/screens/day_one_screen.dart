import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/onboarding/data/models/day_one_models.dart';
import 'package:lms/features/onboarding/presentation/day_one_navigation.dart';
import 'package:lms/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:lms/shared/utils/app_snackbar.dart';
import 'package:lms/shared/widgets/app_bar.dart';

class DayOneScreen extends ConsumerStatefulWidget {
  const DayOneScreen({super.key});

  @override
  ConsumerState<DayOneScreen> createState() => _DayOneScreenState();
}

class _DayOneScreenState extends ConsumerState<DayOneScreen> {
  bool _syncing = false;
  String? _completingKey;

  Future<void> _refresh({bool sync = false}) async {
    if (sync) {
      setState(() => _syncing = true);
      try {
        await ref.read(onboardingApiServiceProvider).syncMyOnboarding();
        ref.invalidate(myOnboardingProvider);
        await ref.read(myOnboardingProvider.future);
        if (mounted) AppSnackbar.success(context, 'Progress updated');
      } catch (e) {
        if (mounted) {
          AppSnackbar.error(
            context,
            e.toString().replaceFirst('Exception: ', ''),
          );
        }
      } finally {
        if (mounted) setState(() => _syncing = false);
      }
      return;
    }

    ref.invalidate(myOnboardingProvider);
    await ref.read(myOnboardingProvider.future);
  }

  Future<void> _markDone(DayOneStep item) async {
    if (item.action != DayOneAction.selfComplete || item.isCompleted) return;
    setState(() => _completingKey = item.key);
    try {
      await ref.read(onboardingApiServiceProvider).completeDayOneStep(item.key);
      ref.invalidate(myOnboardingProvider);
      await ref.read(myOnboardingProvider.future);
      if (mounted) {
        AppSnackbar.success(context, '${item.label} marked complete');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _completingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myOnboardingProvider);
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'Day-one Guide',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _syncing ? null : () => _refresh(sync: true),
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _refresh(),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          if (data.isInactive) {
            return _InactiveCard(
              onBack: () => Navigator.pop(context),
            );
          }

          final items = data.dayOne.items;
          final progress = data.dayOne.progressPercent;
          final status = data.onboardingStatus.replaceAll('_', ' ');

          // Last step done → retire the guide for this user.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            markDayOneFinishedIfComplete(ref, data);
          });

          return RefreshIndicator(
            onRefresh: () => _refresh(sync: true),
            child: ListView(
              physics: isIOS
                  ? const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    )
                  : const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                Text(
                  'Your first-week checklist to get productive fast',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                _ProgressCard(
                  completed: data.dayOne.completed,
                  total: data.dayOne.total,
                  progress: progress,
                  status: status,
                ),
                const SizedBox(height: 16),
                ...items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _StepCard(
                      index: index + 1,
                      item: item,
                      completing: _completingKey == item.key,
                      onGo: () => openDayOneStep(context, item),
                      onMarkDone: () => _markDone(item),
                    ),
                  );
                }),
                if (progress >= 100) ...[
                  const SizedBox(height: 8),
                  _CompleteCard(onBack: () => Navigator.pop(context)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int completed;
  final int total;
  final int progress;
  final String status;

  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.progress,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall progress',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$completed of $total steps complete',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                Text(
                  '$progress%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (progress.clamp(0, 100)) / 100,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Onboarding status: $status',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int index;
  final DayOneStep item;
  final bool completing;
  final VoidCallback onGo;
  final VoidCallback onMarkDone;

  const _StepCard({
    required this.index,
    required this.item,
    required this.completing,
    required this.onGo,
    required this.onMarkDone,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = item.isCompleted;

    return Card(
      color: done ? const Color(0xFFF0FDF4) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: done ? const Color(0xFFA7F3D0) : scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: done
                      ? const Color(0xFF059669)
                      : scheme.surfaceContainerHighest,
                  foregroundColor: done ? Colors.white : scheme.onSurface,
                  child: done
                      ? const Icon(Icons.check, size: 20)
                      : Text(
                          '$index',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: done
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              done ? 'Done' : 'Pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: done
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      if (item.key == 'complete_profile' &&
                          item.progressPercent != null &&
                          !done)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Profile checklist: ${item.progressPercent}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0369A1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.action == DayOneAction.password && !done)
                  SizedBox(
                    width: 180,
                    child: Text(
                      'Use the forced password change on first login',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (item.route != null && item.route!.isNotEmpty)
                  done
                      ? OutlinedButton.icon(
                          onPressed: onGo,
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Open again'),
                        )
                      : FilledButton.icon(
                          onPressed: onGo,
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Go'),
                        ),
                if (item.action == DayOneAction.selfComplete && !done)
                  OutlinedButton(
                    onPressed: completing ? null : onMarkDone,
                    child: Text(completing ? 'Saving…' : 'Mark done'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InactiveCard extends StatelessWidget {
  final VoidCallback onBack;

  const _InactiveCard({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No active onboarding yet',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Day-one guide appears once HR starts onboarding for your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: onBack, child: const Text('Back to Home')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompleteCard extends StatelessWidget {
  final VoidCallback onBack;

  const _CompleteCard({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFECFDF5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFA7F3D0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Day-one complete — nice work',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF064E3B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep finishing any remaining My Details items so HR can verify your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF065F46), fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onBack, child: const Text('Back to Home')),
          ],
        ),
      ),
    );
  }
}
