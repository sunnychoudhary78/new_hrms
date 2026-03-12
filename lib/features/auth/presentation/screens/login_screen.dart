import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lms/core/providers/global_actions_provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _obscurePassword = true;

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    ref.listen(globalActionProvider, (previous, next) {
      if (next == null) return;

      if (next.type == GlobalActionType.error) {
        _showSnack(next.message);
      }
    });

    final size = MediaQuery.of(context).size;
    final bool isWide = size.width > 600;
    final double cardWidth = isWide ? 420 : size.width * 0.9;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: SingleChildScrollView(
          child:
              Container(
                    width: cardWidth,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 32,
                    ),
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
                      border: Border.all(
                        color: scheme.outline.withOpacity(0.06),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// Title
                        ///
                        /// LOGO
                        SizedBox(
                              height: 110,
                              child: Image.asset(
                                "assets/images/hrms_logo.png",
                                fit: BoxFit.contain,
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .scale(
                              begin: const Offset(0.8, 0.8),
                              end: const Offset(1, 1),
                              curve: Curves.easeOutBack,
                            ),

                        const SizedBox(height: 24),

                        Text(
                              "Welcome Back",
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.2, end: 0),

                        const SizedBox(height: 8),

                        Text(
                          "Sign in to continue",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withOpacity(0.6),
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                        const SizedBox(height: 36),

                        /// Email / Employee ID
                        _label(context, "EMAIL OR EMPLOYEE ID"),
                        const SizedBox(height: 8),
                        TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.text,
                              decoration: _input(
                                context,
                                hint: "Enter email or employee ID",
                                icon: Icons.person_outline,
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 300.ms)
                            .slideX(begin: -0.1, end: 0),

                        const SizedBox(height: 20),

                        /// Password
                        _label(context, "PASSWORD"),
                        const SizedBox(height: 8),
                        TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration:
                                  _input(
                                    context,
                                    hint: "Enter password",
                                    icon: Icons.lock_outline,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                            )
                            .animate()
                            .fadeIn(delay: 400.ms)
                            .slideX(begin: 0.1, end: 0),

                        SizedBox(height: 25),

                        /// Login Button
                        SizedBox(
                              height: 52,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: authState.isLoading
                                    ? null
                                    : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: scheme.primary,
                                  foregroundColor: scheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
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
                                        "Sign in",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 500.ms)
                            .scale(
                              begin: const Offset(0.9, 0.9),
                              end: const Offset(1, 1),
                              curve: Curves.easeOutBack,
                            ),
                        const SizedBox(height: 32),

                        /// Forgot Password
                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, "/forgot-password");
                            },
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutCubic,
                  ),
        ),
      ),
    );
  }

  void _handleLogin() async {
    final emailOrEmpId = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (emailOrEmpId.isEmpty || password.isEmpty) {
      _showSnack("Please fill in both fields");
      return;
    }

    /// 🔴 VERY IMPORTANT
    /// Reset expired state before attempting login again
    ref.read(authProvider.notifier).resetSubscriptionExpired();

    await ref.read(authProvider.notifier).login(emailOrEmpId, password);
  }

  Widget _label(BuildContext context, String t) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        t,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface.withOpacity(0.6),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  InputDecoration _input(
    BuildContext context, {
    required String hint,
    required IconData icon,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: scheme.surfaceVariant.withOpacity(0.3),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    );
  }
}
