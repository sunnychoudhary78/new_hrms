import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showSnack("Please enter your email");
      return;
    }

    try {
      await ref.read(authProvider.notifier).forgotPassword(email);

      _showSnack("OTP sent to your email");

      Navigator.pushNamed(context, "/reset-password", arguments: email);
    } catch (_) {
      _showSnack("Failed to send OTP");
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final size = MediaQuery.of(context).size;
    final bool isWide = size.width > 600;
    final double cardWidth = isWide ? 420 : size.width * 0.9;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text("Forgot Password"), centerTitle: true),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Container(
            width: cardWidth,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
              border: Border.all(color: scheme.outline.withOpacity(0.06)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// Icon
                Icon(
                  Icons.lock_reset,
                  size: 64,
                  color: scheme.primary,
                ).animate().fadeIn(duration: 400.ms).scale(),

                const SizedBox(height: 24),

                Text(
                  "Reset your password",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ).animate().fadeIn().slideY(begin: 0.2),

                const SizedBox(height: 8),

                Text(
                  "Enter your email to receive OTP",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.6),
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 36),

                /// Email field
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "EMAIL",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withOpacity(0.6),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "Enter your email",
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: scheme.surfaceVariant.withOpacity(0.3),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 32),

                /// Send OTP button
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleSendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: authState.isLoading
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: scheme.onPrimary,
                            ),
                          )
                        : const Text(
                            "Send OTP",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
          ).animate().fadeIn().scale(),
        ),
        ),
      ),
    );
  }
}
