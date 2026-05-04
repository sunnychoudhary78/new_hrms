import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/network/api_constants.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/kra/data/models/kra_model.dart';
import 'package:lms/features/kra/presentation/providers/kra_provider.dart';
import 'package:lms/features/kra/presentation/widgets/kra_management_tab.dart';
import 'package:lms/features/kra/presentation/widgets/kra_ui_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class KraReviewTab extends ConsumerWidget {
  final KraReviewMode mode;

  const KraReviewTab({super.key, required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evaluationsAsync = ref.watch(kraEvaluationsProvider(mode));
    final permissions = ref.watch(
      authProvider.select((s) => s.permissions.toSet()),
    );
    final canManageKra = ref.watch(canManageKraProvider);

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
                      ref: ref,
                      evaluation: evaluation,
                      mode: mode,
                      canSubmit: KraReviewTab.canSubmitEvaluation(
                        evaluation.statusNormalized,
                        mode,
                        permissions,
                        canManageKra,
                      ),
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
      KraReviewMode.self =>
        'Rate every KPI 1–5, add required remarks, then submit. Files optional. Submit stays disabled until each row is complete.',
      KraReviewMode.team =>
        'Your 1–5 and remarks are required for each KPI; files optional. Empty requests are not sent.',
      KraReviewMode.department =>
        'HOD: 1–5 and remarks required per KPI; files optional. Complete the sheet before submit.',
      KraReviewMode.all =>
        'HR overview: read-only view of ratings and workflow status across the company.',
    };
  }

  /// Submit is driven by evaluation [statusNormalized] and the review lane
  /// permission, or `kra.manage` (KRA setup) when lane tokens are omitted.
  /// [statusNormalized] = [normalizeKraEvaluationStatus] of raw API status.
  static bool canSubmitEvaluation(
    String statusNormalized,
    KraReviewMode mode,
    Set<String> permissions,
    bool canManageKra,
  ) {
    switch (mode) {
      case KraReviewMode.self:
        return statusNormalized == 'PENDING_SELF' &&
            permissions.contains('kra.myrating');
      case KraReviewMode.team:
        return statusNormalized == 'PENDING_MANAGER' &&
            (permissions.contains('kra.teamrating') || canManageKra);
      case KraReviewMode.department:
        return statusNormalized == 'PENDING_HOD' &&
            (permissions.contains('kra.department') || canManageKra);
      case KraReviewMode.all:
        // HR / company-wide list: view only (backend completes at HOD).
        return false;
    }
  }
}

class _EvaluationCard extends StatelessWidget {
  final WidgetRef ref;
  final KraEvaluation evaluation;
  final KraReviewMode mode;
  final bool canSubmit;

  const _EvaluationCard({
    required this.ref,
    required this.evaluation,
    required this.mode,
    required this.canSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final assignedKrasAsync = mode == KraReviewMode.self && canSubmit
        ? ref.watch(myKrasProvider)
        : null;
    final inputRatings = _inputRatingsFor(
      evaluation: evaluation,
      mode: mode,
      assignedKras: assignedKrasAsync?.value,
    );
    final isLoadingAssignedKpis =
        assignedKrasAsync?.isLoading == true &&
        inputRatings.isEmpty &&
        evaluation.ratings.isEmpty;

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
          const SizedBox(height: 6),
          Text(
            _workflowHint(evaluation.statusNormalized),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
                text: evaluation.statusNormalized == 'COMPLETED'
                    ? 'Final ${evaluation.finalScore.toStringAsFixed(1)}'
                    : 'Final score pending',
              ),
              KraMetaPill(
                icon: Icons.checklist_rtl,
                text:
                    '${inputRatings.isNotEmpty ? inputRatings.length : evaluation.ratings.length} KPI(s)',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (evaluation.ratings.isNotEmpty)
            _EvaluationRatingsSummary(evaluation: evaluation, compact: true)
          else if (inputRatings.isNotEmpty)
            _PendingSelfKpiPreview(ratings: inputRatings)
          else
            _EvaluationRatingsSummary(evaluation: evaluation, compact: true),
          if (isLoadingAssignedKpis) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 8),
            Text(
              'Loading your assigned KPIs for self-assessment...',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          if (canSubmit && evaluation.ratings.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              inputRatings.isEmpty
                  ? 'No KPI rows are attached to this evaluation yet. Loading assigned KRAs, or pull to refresh if they were just created.'
                  : 'This new evaluation will create rating rows from your assigned KRA when you submit.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (canSubmit && inputRatings.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.rate_review_rounded),
                label: Text(_submitLabel(mode)),
                onPressed: () {
                  ref.read(kraActionProvider.notifier).resetActionState();
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useRootNavigator: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    builder: (_) => _RatingSheet(
                      evaluation: evaluation,
                      mode: mode,
                      ratingItems: inputRatings,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _workflowHint(String statusNormalized) {
    return switch (statusNormalized) {
      'PENDING_SELF' => 'Waiting on employee self-assessment.',
      'PENDING_MANAGER' => 'With manager for review.',
      'PENDING_HOD' => 'With HOD for final review.',
      'COMPLETED' => 'HOD completed review; final score recorded.',
      _ => 'Status: $statusNormalized',
    };
  }

  static List<KraRating> _inputRatingsFor({
    required KraEvaluation evaluation,
    required KraReviewMode mode,
    required List<KraModel>? assignedKras,
  }) {
    if (mode != KraReviewMode.self || evaluation.ratings.isNotEmpty) {
      return evaluation.ratings;
    }
    if (assignedKras == null || assignedKras.isEmpty) return const [];

    final seen = <String>{};
    final items = <KraRating>[];
    for (final kra in assignedKras) {
      for (final kpi in kra.kpis) {
        if (kpi.id.trim().isEmpty || !seen.add(kpi.id)) continue;
        items.add(KraRating(id: 'draft-${kpi.id}', kpiId: kpi.id, kpi: kpi));
      }
    }
    return items;
  }

  static String _submitLabel(KraReviewMode mode) {
    return switch (mode) {
      KraReviewMode.self => 'Submit self-assessment',
      KraReviewMode.team => 'Submit manager review',
      KraReviewMode.department => 'Submit HOD review',
      KraReviewMode.all => 'Submit',
    };
  }
}

class _PendingSelfKpiPreview extends StatelessWidget {
  final List<KraRating> ratings;

  const _PendingSelfKpiPreview({required this.ratings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = ratings.take(4).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ready for self-assessment',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Icon(Icons.flag_rounded, size: 15, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.kpi?.name ?? 'KPI',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (item.kpi != null)
                    Text(
                      '${item.kpi!.weightage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          if (ratings.length > visible.length)
            Text(
              '+${ratings.length - visible.length} more KPI(s)',
              style: TextStyle(fontSize: 12, color: scheme.primary),
            ),
        ],
      ),
    );
  }
}

class _EvaluationRatingsSummary extends StatelessWidget {
  final KraEvaluation evaluation;
  final bool compact;

  const _EvaluationRatingsSummary({
    required this.evaluation,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratings = evaluation.ratings;
    if (ratings.isEmpty) {
      return Text(
        'No KPI rows',
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }

    final maxRows = compact ? 4 : ratings.length;
    final visible = ratings.take(maxRows).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KPI ratings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: compact ? 12 : 13,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        for (final r in visible) ...[
          Text(
            r.kpi?.name ?? 'KPI',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          _ratingLine(
            context,
            compact,
            'Self',
            r.employeeRating,
            r.employeeRemarks,
            r.employeeDocument,
          ),
          _ratingLine(
            context,
            compact,
            'Mgr',
            r.managerRating,
            r.managerRemarks,
            r.managerDocument,
          ),
          _ratingLine(
            context,
            compact,
            'HOD',
            r.hodRating,
            r.hodRemarks,
            r.hodDocument,
          ),
          if (r.kpi != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 2),
              child: Text(
                'Weight ${r.kpi!.weightage.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
            ),
        ],
        if (compact && ratings.length > maxRows)
          Text(
            '+${ratings.length - maxRows} more KPI(s) — open submit sheet to see all.',
            style: TextStyle(fontSize: 12, color: scheme.primary),
          ),
      ],
    );
  }

  static Widget _ratingLine(
    BuildContext context,
    bool compact,
    String role,
    double? stars,
    String? remarks,
    String? document,
  ) {
    final rm = remarks?.trim();
    final doc = document?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              role,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          KraStarRatingDisplay(rating: stars, iconSize: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              rm != null && rm.isNotEmpty ? rm : '—',
              maxLines: compact ? 1 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (doc != null && doc.isNotEmpty)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'View evidence',
              onPressed: () => _openKraDocument(context, doc),
              icon: Icon(
                Icons.attach_file_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingSheet extends ConsumerStatefulWidget {
  final KraEvaluation evaluation;
  final KraReviewMode mode;
  final List<KraRating> ratingItems;

  const _RatingSheet({
    required this.evaluation,
    required this.mode,
    required this.ratingItems,
  });

  @override
  ConsumerState<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<_RatingSheet> {
  final Map<String, int> _ratings = {};
  final Map<String, TextEditingController> _remarks = {};
  final Map<String, String> _documents = {};

  void _onRemarksTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    for (final rating in widget.ratingItems) {
      final current = _currentRatingForMode(rating, widget.mode);
      _ratings[rating.kpiId] = current?.round().clamp(0, 5) ?? 0;
      final c = TextEditingController(
        text: _currentRemarksForMode(rating, widget.mode) ?? '',
      );
      c.addListener(_onRemarksTextChanged);
      _remarks[rating.kpiId] = c;
    }
  }

  bool get _isFormComplete {
    if (widget.ratingItems.isEmpty) return false;
    for (final item in widget.ratingItems) {
      if (item.kpiId.trim().isEmpty) return false;
      final stars = _ratings[item.kpiId] ?? 0;
      if (stars < 1 || stars > 5) return false;
      final t = _remarks[item.kpiId]?.text.trim() ?? '';
      if (t.isEmpty) return false;
    }
    return true;
  }

  @override
  void dispose() {
    for (final controller in _remarks.values) {
      controller.removeListener(_onRemarksTextChanged);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(kraActionProvider);
    final scheme = Theme.of(context).colorScheme;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sheetTitle(widget.mode),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  _sheetSubtitle(widget.mode),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.evaluation.ratings.isNotEmpty) ...[
                  _EvaluationRatingsSummary(
                    evaluation: widget.evaluation,
                    compact: false,
                  ),
                  const Divider(height: 28),
                ] else ...[
                  _SelfAssessmentNotice(count: widget.ratingItems.length),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Your input',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                for (final item in widget.ratingItems)
                  _RatingInputTile(
                    mode: widget.mode,
                    item: item,
                    selectedStars: _ratings[item.kpiId] ?? 0,
                    onStarsChanged: (v) =>
                        setState(() => _ratings[item.kpiId] = v),
                    remarksController: _remarks[item.kpiId]!,
                    documentPath: _documents[item.kpiId],
                    onPick: () => _pickDocument(item.kpiId),
                    onRemoveDocument: () =>
                        setState(() => _documents.remove(item.kpiId)),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: action.isLoading || !_isFormComplete
                        ? null
                        : _submit,
                    child: action.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_submitLabel(widget.mode)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _sheetTitle(KraReviewMode mode) {
    return switch (mode) {
      KraReviewMode.self => 'Self-assessment',
      KraReviewMode.team => 'Manager review',
      KraReviewMode.department => 'HOD review',
      KraReviewMode.all => 'Rating',
    };
  }

  String _sheetSubtitle(KraReviewMode mode) {
    return switch (mode) {
      KraReviewMode.self =>
        '1–5 stars and remarks (required) per KPI; attach files if needed. The submit button only enables when every field is set.',
      KraReviewMode.team =>
        '1–5 and remarks (required) per KPI; files optional. Disabled submit = incomplete row.',
      KraReviewMode.department =>
        '1–5 and remarks (required) per KPI; files optional. Disabled submit = incomplete row.',
      KraReviewMode.all => '',
    };
  }

  String _submitLabel(KraReviewMode mode) {
    return switch (mode) {
      KraReviewMode.self => 'Submit to manager',
      KraReviewMode.team => 'Submit to HOD',
      KraReviewMode.department => 'Complete review',
      KraReviewMode.all => 'Submit',
    };
  }

  Future<void> _pickDocument(String kpiId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx', 'xlsx', 'csv'],
    );
    final picked = result?.files.single;
    final path = picked?.path;
    if (path != null && path.trim().isNotEmpty) {
      final size = picked?.size ?? await File(path).length();
      if (size > 5 * 1024 * 1024) {
        ref
            .read(globalLoadingProvider.notifier)
            .showError('File size exceeds the 5 MB KRA upload limit.');
        return;
      }
      setState(() => _documents[kpiId] = path);
    }
  }

  Future<void> _submit() async {
    if (widget.ratingItems.isEmpty) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError(
            'This evaluation has no KPI rows. Pull to refresh, then try again.',
          );
      return;
    }

    final g = ref.read(globalLoadingProvider.notifier);
    final payload = <Map<String, dynamic>>[];
    for (final item in widget.ratingItems) {
      if (item.kpiId.trim().isEmpty) {
        g.showError(
          'A KPI in this rating row has no id — try refreshing the list.',
        );
        return;
      }
      final stars = _ratings[item.kpiId] ?? 0;
      if (stars < 1 || stars > 5) {
        g.showError('Select 1–5 stars for ${item.kpi?.name ?? 'each KPI'}.');
        return;
      }
      final rem = _remarks[item.kpiId]!.text.trim();
      if (rem.isEmpty) {
        g.showError('Add remarks for ${item.kpi?.name ?? 'each KPI'}.');
        return;
      }
      payload.add({
        'kpi_id': int.tryParse(item.kpiId) ?? item.kpiId,
        'rating': stars,
        'remarks': rem,
      });
    }

    final confirmed = await _confirmSubmit(context, widget.mode);
    if (confirmed != true) return;

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
      ref.read(globalLoadingProvider.notifier).showError('${state.error}');
      return;
    }
    Navigator.pop(context);
    ref
        .read(globalLoadingProvider.notifier)
        .showSuccess('Ratings submitted successfully');
  }

  static double? _currentRatingForMode(KraRating rating, KraReviewMode mode) {
    return switch (mode) {
      KraReviewMode.self => rating.employeeRating,
      KraReviewMode.team => rating.managerRating,
      KraReviewMode.department => rating.hodRating,
      KraReviewMode.all => null,
    };
  }

  static String? _currentRemarksForMode(KraRating rating, KraReviewMode mode) {
    return switch (mode) {
      KraReviewMode.self => rating.employeeRemarks,
      KraReviewMode.team => rating.managerRemarks,
      KraReviewMode.department => rating.hodRemarks,
      KraReviewMode.all => null,
    };
  }
}

class _SelfAssessmentNotice extends StatelessWidget {
  final int count;

  const _SelfAssessmentNotice({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count KPI(s) are loaded from your manager-assigned KRA. Submitting will create your self-rating rows and forward them to your manager.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingInputTile extends StatelessWidget {
  final KraReviewMode mode;
  final KraRating item;
  final int selectedStars;
  final ValueChanged<int> onStarsChanged;
  final TextEditingController remarksController;
  final String? documentPath;
  final VoidCallback onPick;
  final VoidCallback onRemoveDocument;

  const _RatingInputTile({
    required this.mode,
    required this.item,
    required this.selectedStars,
    required this.onStarsChanged,
    required this.remarksController,
    required this.documentPath,
    required this.onPick,
    required this.onRemoveDocument,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.kpi?.name ?? 'KPI',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            if ((item.kpi?.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.kpi!.description,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            if (mode != KraReviewMode.self) ...[
              const SizedBox(height: 10),
              _priorPanel(mode: mode, item: item, scheme: scheme),
            ],
            const SizedBox(height: 12),
            KraStarRatingPicker(
              value: selectedStars,
              onChanged: onStarsChanged,
              label: switch (mode) {
                KraReviewMode.self => 'Your rating *',
                KraReviewMode.team => 'Manager rating *',
                KraReviewMode.department => 'HOD rating *',
                KraReviewMode.all => 'Rating *',
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: remarksController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: switch (mode) {
                  KraReviewMode.self => 'Remarks (required) *',
                  KraReviewMode.team => 'Manager remarks (required) *',
                  KraReviewMode.department => 'HOD remarks (required) *',
                  KraReviewMode.all => 'Remarks (required) *',
                },
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: documentPath == null
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
                    : scheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: documentPath == null
                      ? scheme.outlineVariant
                      : scheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        documentPath == null
                            ? Icons.cloud_upload_outlined
                            : Icons.attach_file_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          documentPath == null
                              ? 'Supporting evidence (optional)'
                              : documentPath!.split(RegExp(r'[\\/]')).last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: documentPath == null
                                ? scheme.onSurfaceVariant
                                : scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PDF, image, DOCX, XLSX or CSV. Max 5 MB.',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onPick,
                        icon: const Icon(Icons.attach_file, size: 18),
                        label: Text(
                          documentPath == null ? 'Attach file' : 'Change file',
                        ),
                      ),
                      if (documentPath != null)
                        TextButton.icon(
                          onPressed: onRemoveDocument,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Remove'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _priorPanel({
    required KraReviewMode mode,
    required KraRating item,
    required ColorScheme scheme,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Submitted earlier',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          if (mode == KraReviewMode.team || mode == KraReviewMode.department)
            _readRow('Employee', item.employeeRating, item.employeeRemarks),
          if (mode == KraReviewMode.department)
            _readRow('Manager', item.managerRating, item.managerRemarks),
        ],
      ),
    );
  }

  static Widget _readRow(String label, double? rating, String? remarks) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              KraStarRatingDisplay(rating: rating, iconSize: 16),
            ],
          ),
          if (remarks != null && remarks.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 72, top: 2),
              child: Text(remarks.trim(), style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

Future<bool?> _confirmSubmit(BuildContext context, KraReviewMode mode) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(switch (mode) {
        KraReviewMode.self => 'Submit self-assessment?',
        KraReviewMode.team => 'Submit manager review?',
        KraReviewMode.department => 'Complete HOD review?',
        KraReviewMode.all => 'Submit rating?',
      }),
      content: Text(switch (mode) {
        KraReviewMode.self =>
          'Your ratings, remarks and evidence will be sent to your manager for review.',
        KraReviewMode.team =>
          'Your manager ratings will be sent to the HOD for final review.',
        KraReviewMode.department =>
          'This will finalize the KRA review and calculate the final score.',
        KraReviewMode.all => 'Submit this rating.',
      }),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Review again'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Submit'),
        ),
      ],
    ),
  );
}

Future<void> _openKraDocument(BuildContext context, String rawPath) async {
  final uri = _kraDocumentUri(rawPath);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open evidence document')),
    );
  }
}

Uri _kraDocumentUri(String rawPath) {
  final t = rawPath.trim();
  if (t.startsWith('http://') || t.startsWith('https://')) {
    return Uri.parse(t);
  }
  final path = t
      .replaceFirst(RegExp(r'^/+'), '')
      .replaceAll(r'\/', '/')
      .replaceAll('\\', '/')
      .split('/')
      .map((segment) => Uri.encodeComponent(Uri.decodeComponent(segment)))
      .join('/');
  final base = ApiConstants.baseUrl.endsWith('/')
      ? ApiConstants.baseUrl
      : '${ApiConstants.baseUrl}/';
  return Uri.parse(base).resolve(path);
}

/// Self tab: active cycle / evaluations (stars, remarks, files) and assigned
/// KRA structure from `GET /kra` in one scroll, matching a single “My KRA” entry point.
class KraMyKraUnifiedTab extends ConsumerWidget {
  const KraMyKraUnifiedTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evalAsync = ref.watch(kraEvaluationsProvider(KraReviewMode.self));
    final krasAsync = ref.watch(myKrasProvider);
    final permissions = ref.watch(
      authProvider.select((s) => s.permissions.toSet()),
    );
    final canManageKra = ref.watch(canManageKraProvider);

    return Column(
      children: [
        KraInfoBanner(
          icon: Icons.person_pin_circle_outlined,
          title: 'My KRA',
          subtitle:
              'Your assigned KRA appears first with KPI targets below it. Self-assessment for the active cycle is in the next section.',
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(kraEvaluationsProvider(KraReviewMode.self));
              ref.invalidate(myKrasProvider);
              ref.invalidate(kraActiveCycleProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
              children: [
                Text(
                  '1. Your assigned KRA & KPIs',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                krasAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Unable to load your KRAs.\n$e'),
                  data: (kraItems) {
                    if (kraItems.isEmpty) {
                      return const Text(
                        'No KRA record is assigned to you in this list yet.',
                      );
                    }
                    return Column(
                      children: [
                        for (int i = 0; i < kraItems.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _KraMyKraAssignmentRow(kra: kraItems[i]),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  '2. This cycle - review & self-assessment',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                evalAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Unable to load evaluations.\n$e',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'No evaluation for you in this period yet. If you use KRA in this company, try pull-to-refresh after a cycle is active.',
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (int i = 0; i < items.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _EvaluationCard(
                            ref: ref,
                            evaluation: items[i],
                            mode: KraReviewMode.self,
                            canSubmit: KraReviewTab.canSubmitEvaluation(
                              items[i].statusNormalized,
                              KraReviewMode.self,
                              permissions,
                              canManageKra,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KraMyKraAssignmentRow extends ConsumerWidget {
  final KraModel kra;

  const _KraMyKraAssignmentRow({required this.kra});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManageKra = ref.watch(canManageKraProvider);
    final me = ref.watch(
      authProvider.select(
        (s) => s.profile?.userId?.toString() ?? s.profile?.id?.toString() ?? '',
      ),
    );
    final isCreator =
        canManageKra &&
        kra.createdBy != null &&
        kra.createdBy!.isNotEmpty &&
        kra.createdBy == me;

    return KraAssignmentCard(
      kra: kra,
      trailing: isCreator
          ? PopupMenuButton<String>(
              onSelected: (v) => _onMenu(context, ref, v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            )
          : null,
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    if (value == 'edit') {
      openKraFormBottomSheet(context, ref, kra: kra);
      return;
    }
    if (value == 'delete') {
      final ok = await _confirmKraDelete(context);
      if (ok == true) {
        await ref.read(kraActionProvider.notifier).deleteKra(kra.id);
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
    }
  }
}

Future<bool?> _confirmKraDelete(BuildContext context) {
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
