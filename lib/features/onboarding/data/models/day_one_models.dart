enum DayOneAction { password, navigate, selfComplete }

class DayOneStep {
  final String key;
  final String label;
  final String description;
  final String? route;
  final DayOneAction action;
  final bool isCompleted;
  final bool auto;
  final int? progressPercent;

  const DayOneStep({
    required this.key,
    required this.label,
    required this.description,
    required this.route,
    required this.action,
    required this.isCompleted,
    required this.auto,
    this.progressPercent,
  });

  factory DayOneStep.fromJson(Map<String, dynamic> j) {
    final actionStr = j['action'] as String? ?? 'navigate';
    return DayOneStep(
      key: j['key'] as String,
      label: j['label'] as String? ?? j['key'] as String,
      description: j['description'] as String? ?? '',
      route: j['route'] as String?,
      action: switch (actionStr) {
        'password' => DayOneAction.password,
        'self_complete' => DayOneAction.selfComplete,
        _ => DayOneAction.navigate,
      },
      isCompleted: j['is_completed'] == true,
      auto: j['auto'] == true,
      progressPercent: _asInt(j['progress_percent']),
    );
  }
}

class DayOneProgress {
  final List<DayOneStep> items;
  final int completed;
  final int total;
  final int progressPercent;
  final Set<String> selfCompleteKeys;

  const DayOneProgress({
    required this.items,
    required this.completed,
    required this.total,
    required this.progressPercent,
    required this.selfCompleteKeys,
  });

  bool get isComplete => total > 0 && completed >= total;
  bool get isIncomplete => total > 0 && completed < total;

  factory DayOneProgress.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return const DayOneProgress(
        items: [],
        completed: 0,
        total: 0,
        progressPercent: 0,
        selfCompleteKeys: {},
      );
    }
    final keys = (j['self_complete_keys'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    final items = (j['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => DayOneStep.fromJson(Map<String, dynamic>.from(e)))
        .where((step) => !_mobileHiddenKeys.contains(step.key))
        .toList();

    final completed = items.where((step) => step.isCompleted).length;

    return DayOneProgress(
      items: items,
      completed: completed,
      total: items.length,
      progressPercent: items.isEmpty
          ? 0
          : ((completed / items.length) * 100).round(),
      selfCompleteKeys: keys.toSet(),
    );
  }
}

/// Steps handled only on web. `complete_profile` needs the My Details wizard,
/// which the mobile app does not have.
const _mobileHiddenKeys = {'complete_profile'};

class OnboardingMe {
  final String? employeeId;
  final String onboardingStatus;
  final DayOneProgress dayOne;

  const OnboardingMe({
    required this.employeeId,
    required this.onboardingStatus,
    required this.dayOne,
  });

  bool get isInactive =>
      onboardingStatus == 'cancelled' ||
      (employeeId == null || employeeId!.isEmpty);

  /// Mobile shows the guide purely by Day-one steps — the HR onboarding status
  /// stays `in_progress` until My Details is filled on web, which the app
  /// cannot do.
  bool get showDashboardBanner => !isInactive && dayOne.isIncomplete;

  factory OnboardingMe.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return const OnboardingMe(
        employeeId: null,
        onboardingStatus: 'not_started',
        dayOne: DayOneProgress(
          items: [],
          completed: 0,
          total: 0,
          progressPercent: 0,
          selfCompleteKeys: {},
        ),
      );
    }
    return OnboardingMe(
      employeeId: j['employee_id']?.toString(),
      onboardingStatus: (j['onboarding_status'] as String?) ?? 'not_started',
      dayOne: DayOneProgress.fromJson(
        j['day_one'] is Map
            ? Map<String, dynamic>.from(j['day_one'] as Map)
            : null,
      ),
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}
