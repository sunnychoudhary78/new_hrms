class FeatureTourStep {
  final String target;
  final String title;
  final String body;

  const FeatureTourStep({
    required this.target,
    required this.title,
    required this.body,
  });
}

const leaveTourSteps = [
  FeatureTourStep(
    target: 'leave-view-balance',
    title: 'View leave balance',
    body:
        'See remaining leave days per type. Open this screen anytime from Leaves.',
  ),
  FeatureTourStep(
    target: 'leave-apply',
    title: 'Apply for leave',
    body:
        'Use Apply Leave to request leave with type, dates, and submit for approval.',
  ),
];

const attendanceTourSteps = [
  FeatureTourStep(
    target: 'attendance-clock-in',
    title: 'Clock In (punch-in)',
    body: 'Start the workday here. Use Punch In when you arrive.',
  ),
  FeatureTourStep(
    target: 'attendance-clock-out',
    title: 'Clock Out (punch-out)',
    body: 'End your session with Punch Out when you leave.',
  ),
];

const policiesTourSteps = [
  FeatureTourStep(
    target: 'policies-list',
    title: 'Company policies',
    body: 'Browse and open PDFs shared by your company.',
  ),
  FeatureTourStep(
    target: 'policies-ack',
    title: 'Confirm you have read them',
    body: 'Tap I’ve reviewed to complete this Day-one step.',
  ),
];

List<FeatureTourStep> featureTourStepsFor(String? tourId) {
  return switch (tourId) {
    'leave' => leaveTourSteps,
    'attendance' => attendanceTourSteps,
    'policies' => policiesTourSteps,
    _ => const [],
  };
}
