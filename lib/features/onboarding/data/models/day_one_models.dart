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
    return DayOneProgress(
      items: (j['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => DayOneStep.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      completed: _asInt(j['completed']) ?? 0,
      total: _asInt(j['total']) ?? 0,
      progressPercent: _asInt(j['progress_percent']) ?? 0,
      selfCompleteKeys: keys.toSet(),
    );
  }
}

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

  /// Matches web dashboard: incomplete Day-one, or status still in progress.
  bool get showDashboardBanner {
    final dayOneIncomplete = dayOne.isIncomplete;
    final status = onboardingStatus;
    return dayOneIncomplete ||
        (status.isNotEmpty &&
            status != 'completed' &&
            status != 'cancelled');
  }

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
