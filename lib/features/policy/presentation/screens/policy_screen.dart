import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lms/core/network/api_constants.dart';
import 'package:lms/features/policy/data/models/policy_model.dart';
import 'package:lms/features/policy/presentation/providers/policy_provider.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class PolicyScreen extends ConsumerWidget {
  const PolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policiesAsync = ref.watch(policiesProvider);
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Policies'),
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
            return _StateCard(
              icon: Icons.policy_outlined,
              title: 'No policies available',
              message: 'Active company policies will appear here.',
              actionLabel: 'Refresh',
              onAction: () => ref.invalidate(policiesProvider),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(policiesProvider),
            child: ListView(
              physics: isIOS
                  ? const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    )
                  : const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isIOS ? 14 : 18),
                    gradient: LinearGradient(
                      colors: [
                        scheme.primaryContainer,
                        scheme.secondaryContainer,
                      ],
                    ),
                  ),
                  child: Text(
                    'View HR policies shared by your company. Tap a policy to open the PDF.',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ...policies.map(
                  (policy) => _PolicyCard(policy: policy, isIOS: isIOS),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final PolicyModel policy;
  final bool isIOS;

  const _PolicyCard({required this.policy, required this.isIOS});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final created = policy.createdAt == null
        ? null
        : DateFormat('dd MMM yyyy').format(policy.createdAt!);
    final meta = [
      if (created != null) created,
      if (policy.fileSize != null) _formatFileSize(policy.fileSize!),
    ].join(' | ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(isIOS ? 12 : 16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(isIOS ? 10 : 12),
          ),
          child: Icon(Icons.picture_as_pdf_rounded, color: scheme.primary),
        ),
        title: Text(
          policy.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            meta.isEmpty ? (policy.originalName ?? 'PDF document') : meta,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        trailing: Icon(Icons.open_in_new_rounded, color: scheme.primary),
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
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(isIOS ? 12 : 16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: scheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
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
