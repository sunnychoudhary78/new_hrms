import 'package:flutter/material.dart';
import 'package:lms/features/onboarding/data/feature_tour_configs.dart';

class FeatureTourOverlay {
  FeatureTourOverlay._();

  static OverlayEntry? _entry;

  static void show({
    required BuildContext context,
    required List<FeatureTourStep> steps,
    required Map<String, GlobalKey> targets,
  }) {
    hide();
    if (steps.isEmpty) return;

    _entry = OverlayEntry(
      builder: (_) => _FeatureTourLayer(
        steps: steps,
        targets: targets,
        onClose: hide,
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }

  static void maybeStart({
    required BuildContext context,
    required String? tourId,
    required Map<String, GlobalKey> targets,
    Duration delay = const Duration(milliseconds: 350),
  }) {
    final steps = featureTourStepsFor(tourId);
    if (steps.isEmpty) return;

    Future<void>.delayed(delay, () {
      if (!context.mounted) return;
      show(context: context, steps: steps, targets: targets);
    });
  }
}

class _FeatureTourLayer extends StatefulWidget {
  final List<FeatureTourStep> steps;
  final Map<String, GlobalKey> targets;
  final VoidCallback onClose;

  const _FeatureTourLayer({
    required this.steps,
    required this.targets,
    required this.onClose,
  });

  @override
  State<_FeatureTourLayer> createState() => _FeatureTourLayerState();
}

class _FeatureTourLayerState extends State<_FeatureTourLayer> {
  int _index = 0;
  Rect? _box;

  FeatureTourStep get _step => widget.steps[_index];
  int get _total => widget.steps.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final key = widget.targets[_step.target];
    final ctx = key?.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    Rect? rect;
    if (box != null && box.hasSize && box.size.width > 0 && box.size.height > 0) {
      final offset = box.localToGlobal(Offset.zero);
      const pad = 8.0;
      rect = Rect.fromLTWH(
        offset.dx - pad,
        offset.dy - pad,
        box.size.width + pad * 2,
        box.size.height + pad * 2,
      );
    }
    setState(() => _box = rect);
  }

  void _next() {
    if (_index >= _total - 1) {
      widget.onClose();
      return;
    }
    setState(() => _index += 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _back() {
    if (_index == 0) return;
    setState(() => _index -= 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final tooltipTop = () {
      final box = _box;
      if (box == null) return size.height * 0.35;
      final spaceBelow = size.height - box.bottom;
      if (spaceBelow > 180 || box.top < 160) {
        return (box.bottom + 12).clamp(16.0, size.height - 220);
      }
      return (box.top - 180).clamp(16.0, size.height - 220);
    }();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(color: const Color(0x800F172A)),
            ),
          ),
          if (_box != null)
            Positioned(
              left: _box!.left,
              top: _box!.top,
              width: _box!.width,
              height: _box!.height,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.primary, width: 2),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            top: tooltipTop,
            child: GestureDetector(
              onTap: () {},
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: scheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'STEP ${_index + 1} OF $_total',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _step.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: widget.onClose,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _step.body,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      if (_box == null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'That control is not visible right now — you may need permission or the page is still loading.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          TextButton(
                            onPressed: widget.onClose,
                            child: const Text('Skip'),
                          ),
                          const Spacer(),
                          if (_index > 0)
                            OutlinedButton(
                              onPressed: _back,
                              child: const Text('Back'),
                            ),
                          if (_index > 0) const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _next,
                            child: Text(_index >= _total - 1 ? 'Done' : 'Next'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
