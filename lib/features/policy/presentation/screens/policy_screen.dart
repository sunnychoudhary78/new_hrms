import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lms/core/network/api_constants.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/onboarding/data/day_one_route.dart';
import 'package:lms/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:lms/features/onboarding/presentation/widgets/feature_tour_overlay.dart';
import 'package:lms/features/policy/data/models/policy_model.dart';
import 'package:lms/features/policy/presentation/providers/policy_provider.dart';
import 'package:lms/shared/utils/app_snackbar.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class PolicyScreen extends ConsumerStatefulWidget {
  const PolicyScreen({super.key});

  @override
  ConsumerState<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends ConsumerState<PolicyScreen> {
  final GlobalKey _listKey = GlobalKey();
  final GlobalKey _ackKey = GlobalKey();
  bool _tourStarted = false;
  bool _acking = false;

  void _maybeStartTour() {
    if (_tourStarted || !mounted) return;
    final tour = tourIdFromArgs(ModalRoute.of(context)?.settings.arguments);
    if (tour != 'policies') return;
    _tourStarted = true;
    FeatureTourOverlay.maybeStart(
      context: context,
      tourId: tour,
      targets: {
        'policies-list': _listKey,
        'policies-ack': _ackKey,
      },
    );
  }

  @override
  void dispose() {
    FeatureTourOverlay.hide();
    super.dispose();
  }

  Future<void> _ackPolicies() async {
    setState(() => _acking = true);
    try {
      await ref
          .read(onboardingApiServiceProvider)
          .completeDayOneStep('day1_read_policies');
      ref.invalidate(myOnboardingProvider);
      if (mounted) {
        AppSnackbar.success(context, 'Policies marked as reviewed');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _acking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policiesAsync = ref.watch(policiesProvider);
    final onboardingAsync = ref.watch(myOnboardingProvider);
    final onboarding = onboardingAsync.asData?.value;
    final policiesStep = onboarding?.dayOne.items.where(
      (s) => s.key == 'day1_read_policies',
    );
    final showAck =
        policiesStep != null &&
        policiesStep.isNotEmpty &&
        !policiesStep.first.isCompleted;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    if (onboardingAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppAppBar(title: 'Policies'),
      bottomNavigationBar: showAck
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm + 4,
                ),
                child: KeyedSubtree(
                  key: _ackKey,
                  child: AppPrimaryButton(
                    label: _acking
                        ? 'Saving…'
                        : "I've reviewed company policies",
                    onPressed: _acking ? null : _ackPolicies,
                    isLoading: _acking,
                  ),
                ),
              ),
            )
          : null,
      body: policiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _StateCard(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load policies',
          message: error.toString(),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(policiesProvider),
        ),
        data: (policies) {
          if (policies.isEmpty) {
            return KeyedSubtree(
              key: _listKey,
              child: _StateCard(
                icon: Icons.policy_outlined,
                title: 'No policies available',
                message: 'Active company policies will appear here.',
                actionLabel: 'Refresh',
                onAction: () => ref.invalidate(policiesProvider),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(policiesProvider),
            child: KeyedSubtree(
              key: _listKey,
              child: ListView(
                physics: isIOS
                    ? const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      )
                    : const AlwaysScrollableScrollPhysics(),
                padding: appScreenPadding,
                children: [
                  const AppHeroBanner(
                    icon: Icons.policy_outlined,
                    title: 'Company policies',
                    message:
                        'View HR policies shared by your company. Tap a policy to open the PDF.',
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),
                  ...policies.map(
                    (policy) => _PolicyCard(policy: policy),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final PolicyModel policy;

  const _PolicyCard({required this.policy});

  @override
  Widget build(BuildContext context) {
    final created = policy.createdAt == null
        ? null
        : DateFormat('dd MMM yyyy').format(policy.createdAt!);
    final meta = [
      if (created != null) created,
      if (policy.fileSize != null) _formatFileSize(policy.fileSize!),
    ].join(' | ');

    return AppSectionCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        leading: AppIconBadge(
          icon: Icons.picture_as_pdf_rounded,
          size: 44,
          backgroundColor: AppColors.iconBg,
          iconColor: AppColors.primary,
        ),
        title: Text(
          policy.title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.title,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            meta.isEmpty ? (policy.originalName ?? 'PDF document') : meta,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
        trailing: Icon(
          Icons.open_in_new_rounded,
          color: AppColors.primary,
        ),
        onTap: () => _openPolicy(context, policy),
      ),
    );
  }

  Future<void> _openPolicy(BuildContext context, PolicyModel policy) async {
    final uri = _policyUri(policy);

    if (uri == null) {
      _showSnack(context, 'Policy file is not available.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      _showSnack(context, 'Unable to open policy PDF.');
    }
  }

  Uri? _policyUri(PolicyModel policy) {
    final rawUrl = policy.fileUrl?.trim();
    if (rawUrl != null &&
        (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))) {
      return Uri.tryParse(rawUrl);
    }

    final fileName = policy.fileName.trim();
    if (fileName.isEmpty) return null;

    final base = ApiConstants.baseUrl.endsWith('/')
        ? ApiConstants.baseUrl.substring(0, ApiConstants.baseUrl.length - 1)
        : ApiConstants.baseUrl;
    final encodedFile = Uri.encodeComponent(fileName);
    return Uri.parse('$base/uploads/policies/$encodedFile');
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: appScreenPadding,
        child: AppSectionCard(
          margin: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconBadge(
                icon: icon,
                size: 52,
                backgroundColor: AppColors.iconBg,
                iconColor: AppColors.primary,
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.title,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              AppSecondaryButton(
                label: actionLabel,
                onPressed: onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes <= 0) return '0 KB';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
