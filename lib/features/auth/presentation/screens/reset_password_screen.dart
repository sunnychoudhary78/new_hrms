import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lms/core/providers/global_loading_provider.dart';

import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  final TextEditingController _passwordController = TextEditingController();

  bool _obscure = true;

  int _secondsRemaining = 30;
  Timer? _timer;

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _startTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardForOtp();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();

    for (var c in _otpControllers) {
      c.dispose();
    }

    for (var f in _otpFocusNodes) {
      f.dispose();
    }

    _passwordController.dispose();

    super.dispose();
  }

  // ─────────────────────────────────────────────
  // TIMER
  // ─────────────────────────────────────────────

  void _startTimer() {
    _secondsRemaining = 30;

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  // ─────────────────────────────────────────────
  // GET OTP STRING
  // ─────────────────────────────────────────────

  String get _otp => _otpControllers.map((c) => c.text).join();

  // ─────────────────────────────────────────────
  // CLIPBOARD OTP AUTO PASTE
  // ─────────────────────────────────────────────

  Future<void> _checkClipboardForOtp() async {
    final data = await Clipboard.getData('text/plain');

    if (data?.text == null) return;

    final text = data!.text!.trim();

    if (text.length == 6 && RegExp(r'^\d{6}$').hasMatch(text)) {
      for (int i = 0; i < 6; i++) {
        _otpControllers[i].text = text[i];
      }

      FocusScope.of(context).unfocus();

      setState(() {});
    }
  }

  // ─────────────────────────────────────────────
  // PASSWORD STRENGTH
  // ─────────────────────────────────────────────

  double _passwordStrength(String password) {
    double strength = 0;

    if (password.length >= 8) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) strength += 0.25;

    return strength;
  }

  // ─────────────────────────────────────────────
  // OTP INPUT HANDLING
  // ─────────────────────────────────────────────

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        FocusScope.of(context).unfocus();

        if (_passwordController.text.trim().isNotEmpty) {
          _handleResetPassword();
        }
      }
    } else {
      if (index > 0) {
        _otpFocusNodes[index - 1].requestFocus();
      }
    }
  }

  Widget _buildOtpField(int index, ColorScheme scheme) {
    return SizedBox(
      width: 48,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: scheme.surfaceVariant.withOpacity(0.3),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (v) => _onOtpChanged(index, v),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // RESET PASSWORD
  // ─────────────────────────────────────────────

  Future<void> _handleResetPassword() async {
    if (_otp.length != 6) {
      ref.read(globalLoadingProvider.notifier).showError("Enter complete OTP");
      return;
    }

    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      ref.read(globalLoadingProvider.notifier).showError("Enter new password");
      return;
    }

    try {
      ref
          .read(globalLoadingProvider.notifier)
          .showLoading("Resetting password...");

      await ref
          .read(authProvider.notifier)
          .resetPassword(email: widget.email, otp: _otp, newPassword: password);

      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess("Password reset successful");

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (_) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError("Invalid OTP or password");
    }
  }

  // ─────────────────────────────────────────────
  // RESEND OTP
  // ─────────────────────────────────────────────

  Future<void> _handleResendOtp() async {
    try {
      ref.read(globalLoadingProvider.notifier).showLoading("Sending OTP...");

      await ref.read(authProvider.notifier).forgotPassword(widget.email);

      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess("OTP sent successfully");

      _startTimer();
    } catch (_) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError("Failed to resend OTP");
    }
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final scheme = Theme.of(context).colorScheme;

    final size = MediaQuery.of(context).size;

    final double cardWidth = size.width > 600 ? 420 : size.width * 0.9;

    final strength = _passwordStrength(_passwordController.text);

    Color strengthColor;
    String strengthText;

    if (strength <= 0.25) {
      strengthColor = Colors.red;
      strengthText = "Weak";
    } else if (strength <= 0.5) {
      strengthColor = Colors.orange;
      strengthText = "Medium";
    } else if (strength <= 0.75) {
      strengthColor = Colors.blue;
      strengthText = "Strong";
    } else {
      strengthColor = Colors.green;
      strengthText = "Very Strong";
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text("Reset Password"), centerTitle: true),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Container(
            width: cardWidth,
            padding: const EdgeInsets.all(28),
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
            ),
            child: Column(
              children: [
                Icon(
                  Icons.security,
                  size: 64,
                  color: scheme.primary,
                ).animate().fadeIn().scale(),

                const SizedBox(height: 24),

                const Text(
                  "Enter verification code",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) => _buildOtpField(i, scheme)),
                ),

                const SizedBox(height: 20),

                if (_secondsRemaining > 0)
                  Text("Resend OTP in $_secondsRemaining sec")
                else
                  TextButton(
                    onPressed: _handleResendOtp,
                    child: const Text("Resend OTP"),
                  ),

                const SizedBox(height: 30),

                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "New password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscure = !_obscure;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: scheme.surfaceVariant.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                LinearProgressIndicator(value: strength, color: strengthColor),

                const SizedBox(height: 4),

                Text(strengthText, style: TextStyle(color: strengthColor)),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: authState.isLoading
                        ? null
                        : _handleResetPassword,
                    child: const Text("Reset Password"),
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
