import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:lms/shared/utils/app_snackbar.dart';

/// Full-screen gate matching web ForcePasswordChange when
/// `user.must_change_password` is true.
class ForcePasswordChangeGate extends ConsumerStatefulWidget {
  const ForcePasswordChangeGate({super.key});

  @override
  ConsumerState<ForcePasswordChangeGate> createState() =>
      _ForcePasswordChangeGateState();
}

class _ForcePasswordChangeGateState
    extends ConsumerState<ForcePasswordChangeGate> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (next.length < 6) {
      AppSnackbar.error(context, 'Password must be at least 6 characters');
      return;
    }
    if (next != confirm) {
      AppSnackbar.error(context, 'Passwords do not match');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(onboardingApiServiceProvider).changePasswordFirstLogin(
            currentPassword: current,
            newPassword: next,
          );
      await ref.read(authProvider.notifier).clearMustChangePassword();
      ref.invalidate(myOnboardingProvider);
      if (mounted) {
        AppSnackbar.success(context, 'Password updated. Welcome!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = ref.watch(authProvider).authUser?.name ??
        ref.watch(authProvider).profile?.associatesName ??
        'there';

    return Material(
      color: const Color(0x990F172A),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                borderRadius: BorderRadius.circular(20),
                color: scheme.surface,
                elevation: 12,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Change your password',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hi $name, please set a new password before continuing.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _currentCtrl,
                        obscureText: !_showCurrent,
                        decoration: InputDecoration(
                          labelText: 'Current / temporary password',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showCurrent = !_showCurrent),
                            icon: Icon(
                              _showCurrent
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _newCtrl,
                        obscureText: !_showNew,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showNew = !_showNew),
                            icon: Icon(
                              _showNew
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmCtrl,
                        obscureText: !_showConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showConfirm = !_showConfirm),
                            icon: Icon(
                              _showConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Update password'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
