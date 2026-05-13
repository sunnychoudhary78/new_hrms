import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/features/kra/data/models/kra_model.dart';
import 'package:lms/shared/widgets/premium_feature_components.dart';

class KraInfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const KraInfoBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumFeatureHeader(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}

class KraStatusChip extends StatelessWidget {
  final String status;

  const KraStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = normalizeKraEvaluationStatus(status);
    final color = switch (s) {
      'COMPLETED' => Colors.green,
      'PENDING_SELF' => Colors.orange,
      'PENDING_MANAGER' => Colors.blue,
      'PENDING_HOD' => Colors.purple,
      _ => Colors.grey,
    };
    return PremiumStatusPill(label: s.replaceAll('_', ' '), color: color);
  }
}

class KraMetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const KraMetaPill({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(isIOS ? 14 : 20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 5),
          Text(text),
        ],
      ),
    );
  }
}

class KraEmptyList extends StatelessWidget {
  final String text;

  const KraEmptyList({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return ListView(
      physics: isIOS
          ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())
          : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Icon(
          Icons.assignment_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 10),
        Center(child: Text(text)),
      ],
    );
  }
}

class KraErrorList extends StatelessWidget {
  final String message;

  const KraErrorList({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return ListView(
      physics: isIOS
          ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())
          : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [Text(message, textAlign: TextAlign.center)],
    );
  }
}

/// Read-only KRA + KPI line items (from `GET /kra`); edit/delete use KRA Setup or creator actions.
class KraAssignmentCard extends StatelessWidget {
  final KraModel kra;
  final Widget? trailing;

  const KraAssignmentCard({super.key, required this.kra, this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final innerRadius = BorderRadius.circular(isIOS ? 12 : 16);
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KRA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 6),
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
              if (trailing != null) trailing!,
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
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: innerRadius,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KPI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (kra.kpis.isEmpty)
                  Text(
                    'No KPI targets added',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                else
                  for (final kpi in kra.kpis)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
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
          ),
        ],
      ),
    );
  }
}

/// Tappable 1–5 star row for KRA ratings (aligned with backend 1–5 scale).
class KraStarRatingPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final String label;

  const KraStarRatingPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Rating',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final selected = value.clamp(0, 5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(5, (i) {
            final starIndex = i + 1;
            final filled = starIndex <= selected;
            return IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              style: IconButton.styleFrom(
                splashFactory: isIOS
                    ? NoSplash.splashFactory
                    : InkSplash.splashFactory,
              ),
              onPressed: () => onChanged(starIndex),
              icon: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 32,
                color: filled ? Colors.amber.shade700 : scheme.outline,
              ),
            );
          }),
        ),
        if (selected > 0)
          Text(
            '$selected / 5',
            style: TextStyle(
              fontSize: 12,
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// Read-only star row from a numeric rating (nullable).
class KraStarRatingDisplay extends StatelessWidget {
  final double? rating;
  final double iconSize;

  const KraStarRatingDisplay({
    super.key,
    required this.rating,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (rating == null) {
      return Text('—', style: TextStyle(color: scheme.onSurfaceVariant));
    }
    final v = rating!.clamp(1, 5).round().clamp(1, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < v ? Icons.star_rounded : Icons.star_outline_rounded,
          size: iconSize,
          color: Colors.amber.shade800,
        ),
      ),
    );
  }
}
