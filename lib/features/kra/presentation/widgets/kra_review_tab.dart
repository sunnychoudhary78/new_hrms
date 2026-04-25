import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/kra/data/models/kra_model.dart';
import 'package:lms/features/kra/presentation/providers/kra_provider.dart';
import 'package:lms/features/kra/presentation/widgets/kra_ui_widgets.dart';

class KraReviewTab extends ConsumerWidget {
  final KraReviewMode mode;

  const KraReviewTab({super.key, required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evaluationsAsync = ref.watch(kraEvaluationsProvider(mode));
    final canManage = ref.watch(canManageKraProvider);

    return Column(
      children: [
        KraInfoBanner(
          icon: Icons.rate_review_rounded,
          title: mode.label,
          subtitle: _subtitleForMode(mode),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(kraEvaluationsProvider(mode)),
            child: evaluationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  KraErrorList(message: 'Unable to load evaluations.\n$e'),
              data: (items) {
                if (items.isEmpty) {
                  return const KraEmptyList(text: 'No evaluations found');
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  itemBuilder: (_, i) {
                    final evaluation = items[i];
                    return _EvaluationCard(
                      evaluation: evaluation,
                      mode: mode,
                      canSubmit: _canSubmit(evaluation.status, mode, canManage),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: items.length,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _subtitleForMode(KraReviewMode mode) {
    return switch (mode) {
      KraReviewMode.self => 'Submit and track your own KPI ratings.',
      KraReviewMode.team => 'Review direct reports pending manager action.',
      KraReviewMode.department =>
        'Review department ratings pending HOD action.',
      KraReviewMode.all => 'Company-wide KRA rating overview.',
    };
  }

  bool _canSubmit(String status, KraReviewMode mode, bool canManage) {
    if (mode == KraReviewMode.self) return status == 'PENDING_SELF';
    if (!canManage) return false;
    if (mode == KraReviewMode.team) return status == 'PENDING_MANAGER';
    if (mode == KraReviewMode.department) return status == 'PENDING_HOD';
    return status == 'PENDING_MANAGER' || status == 'PENDING_HOD';
  }
}

class _EvaluationCard extends StatelessWidget {
  final KraEvaluation evaluation;
  final KraReviewMode mode;
  final bool canSubmit;

  const _EvaluationCard({
    required this.evaluation,
    required this.mode,
    required this.canSubmit,
  });

  @override
  Widget build(BuildContext context) {
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
            children: [
              Expanded(
                child: Text(
                  evaluation.employee?.name ?? 'Employee',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              KraStatusChip(status: evaluation.status),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              KraMetaPill(
                icon: Icons.calendar_month,
                text: evaluation.cycle?.label ?? 'Cycle ${evaluation.cycleId}',
              ),
              KraMetaPill(
                icon: Icons.star_rounded,
                text: 'Score ${evaluation.finalScore.toStringAsFixed(1)}',
              ),
              KraMetaPill(
                icon: Icons.checklist_rtl,
                text: '${evaluation.ratings.length} KPI(s)',
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final rating in evaluation.ratings.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${rating.kpi?.name ?? 'KPI'} - ${rating.kpi?.weightage.toStringAsFixed(0) ?? '0'}%',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          if (evaluation.ratings.length > 3)
            Text(
              '+${evaluation.ratings.length - 3} more KPI(s)',
              style: TextStyle(color: scheme.primary),
            ),
          if (canSubmit) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.rate_review_rounded),
                label: const Text('Submit Rating'),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      _RatingSheet(evaluation: evaluation, mode: mode),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingSheet extends ConsumerStatefulWidget {
  final KraEvaluation evaluation;
  final KraReviewMode mode;

  const _RatingSheet({required this.evaluation, required this.mode});

  @override
  ConsumerState<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<_RatingSheet> {
  final Map<String, TextEditingController> _ratings = {};
  final Map<String, TextEditingController> _remarks = {};
  final Map<String, String> _documents = {};

  @override
  void initState() {
    super.initState();
    for (final rating in widget.evaluation.ratings) {
      _ratings[rating.kpiId] = TextEditingController();
      _remarks[rating.kpiId] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _ratings.values) {
      controller.dispose();
    }
    for (final controller in _remarks.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              Text(
                'Submit Rating',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final item in widget.evaluation.ratings)
                _RatingInputTile(
                  item: item,
                  ratingController: _ratings[item.kpiId]!,
                  remarksController: _remarks[item.kpiId]!,
                  documentPath: _documents[item.kpiId],
                  onPick: () => _pickDocument(item.kpiId),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: action.isLoading ? null : _submit,
                  child: action.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDocument(String kpiId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx', 'xlsx', 'csv'],
    );
    final path = result?.files.single.path;
    if (path != null && path.trim().isNotEmpty) {
      setState(() => _documents[kpiId] = path);
    }
  }

  Future<void> _submit() async {
    final payload = <Map<String, dynamic>>[];
    for (final item in widget.evaluation.ratings) {
      final rating = double.tryParse(_ratings[item.kpiId]!.text.trim());
      if (rating == null || rating < 1 || rating > 5) {
        _snack('Enter rating between 1 and 5 for ${item.kpi?.name ?? 'KPI'}');
        return;
      }
      payload.add({
        'kpi_id': item.kpiId,
        'rating': rating == rating.roundToDouble() ? rating.toInt() : rating,
        'remarks': _remarks[item.kpiId]!.text.trim(),
      });
    }

    await ref
        .read(kraActionProvider.notifier)
        .submitRating(
          evaluationId: widget.evaluation.id,
          mode: widget.mode,
          ratings: payload,
          documentPathsByKpi: _documents,
        );
    final state = ref.read(kraActionProvider);
    if (!mounted) return;
    if (state.hasError) {
      _snack('Error: ${state.error}');
      return;
    }
    Navigator.pop(context);
    _snack('Rating submitted');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RatingInputTile extends StatelessWidget {
  final KraRating item;
  final TextEditingController ratingController;
  final TextEditingController remarksController;
  final String? documentPath;
  final VoidCallback onPick;

  const _RatingInputTile({
    required this.item,
    required this.ratingController,
    required this.remarksController,
    required this.documentPath,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.kpi?.name ?? 'KPI',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if ((item.kpi?.description ?? '').isNotEmpty)
              Text(item.kpi!.description),
            const SizedBox(height: 8),
            TextField(
              controller: ratingController,
              decoration: const InputDecoration(labelText: 'Rating (1-5) *'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: remarksController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Remarks'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.attach_file),
              label: Text(
                documentPath == null ? 'Attach document' : 'Change document',
              ),
            ),
            if (documentPath != null)
              Text(
                documentPath!.split(RegExp(r'[\\/]')).last,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
