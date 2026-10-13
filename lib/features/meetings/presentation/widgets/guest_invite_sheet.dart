import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/meetings/presentation/meetings_access.dart';
import 'package:lms/features/meetings/presentation/providers/meetings_providers.dart';
import 'package:lms/shared/utils/app_snackbar.dart';
import 'package:share_plus/share_plus.dart';

Future<void> showGuestInviteSheet(
  BuildContext context,
  WidgetRef ref,
  String meetingId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: defaultTargetPlatform == TargetPlatform.iOS,
    builder: (_) => GuestInviteSheet(meetingId: meetingId),
  );
}

class GuestInviteSheet extends ConsumerStatefulWidget {
  const GuestInviteSheet({super.key, required this.meetingId});

  final String meetingId;

  @override
  ConsumerState<GuestInviteSheet> createState() => _GuestInviteSheetState();
}

class _GuestInviteSheetState extends ConsumerState<GuestInviteSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  String? _lastUrl;
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) AppSnackbar.success(context, 'Copied to clipboard');
  }

  Future<void> _share(String url) async {
    await SharePlus.instance.share(
      ShareParams(text: url, subject: 'Meeting link'),
    );
  }

  Future<String?> _ensureInviteUrl({required bool emailToo}) async {
    final invite = await ref.read(meetingsRepositoryProvider).createGuestInvite(
          widget.meetingId,
          name: _name.text.trim(),
          email: _email.text.trim(),
          sendEmail: emailToo,
        );
    if (!mounted) return null;
    setState(() => _lastUrl = invite.inviteUrl);
    return invite.inviteUrl;
  }

  Future<void> _invite({required bool emailToo}) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final url = await _ensureInviteUrl(emailToo: emailToo);
      if (!mounted || url == null || url.isEmpty) return;
      await _copy(url);
      if (!mounted) return;
      if (emailToo) {
        AppSnackbar.success(context, 'Guest email will be sent shortly');
      } else {
        AppSnackbar.success(
          context,
          'Guest link copied — they wait in lobby until you admit them',
        );
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, cleanApiError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _shareLink() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final existing = _lastUrl;
      final url = (existing != null && existing.isNotEmpty)
          ? existing
          : await _ensureInviteUrl(emailToo: false);
      if (!mounted || url == null || url.isEmpty) return;
      await _share(url);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, cleanApiError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, viewInsets + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invite guest (lobby)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Guests open the link and wait in the Meet lobby. You must join as host and admit them — the link alone does not let them into the call.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Guest name (optional)',
                hintText: 'Guest',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Guest email (optional)',
                hintText: 'guest@example.com',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_lastUrl != null) ...[
              const SizedBox(height: 12),
              Text(
                'Last invite link',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _lastUrl!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () => _copy(_lastUrl!),
                  ),
                  IconButton(
                    tooltip: 'Share',
                    icon: const Icon(Icons.share_rounded),
                    onPressed: () => _share(_lastUrl!),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sending ? null : () => _invite(emailToo: false),
              icon: const Icon(Icons.link_rounded),
              label: Text(_sending ? 'Creating…' : 'Copy guest link'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _sending ? null : _shareLink,
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share meeting link'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _sending || _email.text.trim().isEmpty
                  ? null
                  : () => _invite(emailToo: true),
              icon: const Icon(Icons.mail_outline_rounded),
              label: const Text('Copy link & email guest'),
            ),
          ],
        ),
      ),
    );
  }
}
