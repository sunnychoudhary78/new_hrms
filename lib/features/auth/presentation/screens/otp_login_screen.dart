import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sms_autofill/sms_autofill.dart';
import '../providers/auth_provider.dart';

class OtpLoginScreen extends ConsumerStatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  ConsumerState<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends ConsumerState<OtpLoginScreen>
    with CodeAutoFill {
  final _phoneController = TextEditingController();

  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _otpSent = false;
  int _resendTimer = 0;
  Timer? _timer;

  final _shakeKey = GlobalKey<ShakeWidgetState>();

  String get _otp => _otpControllers.map((e) => e.text).join();

  @override
  void initState() {
    super.initState();
    listenForCode();

    SmsAutoFill().getAppSignature.then((signature) {
      debugPrint("SMS App Signature: $signature");
    });
  }

  @override
  void dispose() {
    cancel();
    _timer?.cancel();

    for (final c in _otpControllers) {
      c.dispose();
    }

    for (final f in _focusNodes) {
      f.dispose();
    }

    _phoneController.dispose();
    super.dispose();
  }

  /// SMS Auto Fill
  @override
  void codeUpdated() {
    if (code == null) return;

    final receivedOtp = code!.trim();

    if (receivedOtp.length == 6) {
      for (int i = 0; i < 6; i++) {
        _otpControllers[i].text = receivedOtp[i];
      }

      _verifyOtp();
    }
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^[0-9]{10}$').hasMatch(phone);
  }

  void _startTimer() {
    _resendTimer = 30;

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer == 0) {
        timer.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();

    if (!_isValidPhone(phone)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter valid phone number")));
      return;
    }

    await ref.read(authProvider.notifier).sendOtp(phone);

    setState(() => _otpSent = true);

    _startTimer();

    Future.delayed(const Duration(milliseconds: 300), () {
      _focusNodes[0].requestFocus();
    });
    _checkClipboardOtp();
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneController.text.trim();

    if (_otp.length != 6) {
      _shakeKey.currentState?.shake(); // 🔥 trigger shake

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter valid OTP")));
      return;
    }

    await ref.read(authProvider.notifier).verifyOtp(phone: phone, otp: _otp);
  }

  void _onOtpChanged(int index, String value) async {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        FocusScope.of(context).unfocus(); // hides keyboard on last digit
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }

    if (_otp.length == 6) {
      _verifyOtp();
    }
  }

  /// Detect paste OTP
  Future<void> _checkClipboardOtp() async {
    final data = await Clipboard.getData('text/plain');

    if (data?.text == null) return;

    final text = data!.text!.trim();

    if (RegExp(r'^\d{6}$').hasMatch(text)) {
      for (int i = 0; i < 6; i++) {
        _otpControllers[i].text = text[i];
      }

      _verifyOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (prev, next) {
      if (next.profile != null) {
        Navigator.pop(context);
      }
    });

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 420,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outline.withOpacity(.06)),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withOpacity(.08),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 60,
                  color: scheme.primary,
                ).animate().scale(duration: 400.ms),

                const SizedBox(height: 20),

                Text(
                  "OTP Login",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "Enter phone number to continue",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(.6),
                  ),
                ),

                const SizedBox(height: 30),

                _PhoneInput(controller: _phoneController),

                const SizedBox(height: 20),

                if (_otpSent)
                  ShakeWidget(
                    key: _shakeKey,
                    child:
                        Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                6,
                                (i) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: OtpDigitField(
                                    controller: _otpControllers[i],
                                    focusNode: _focusNodes[i],
                                    onChanged: (v) => _onOtpChanged(i, v),
                                  ),
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: .1, end: 0),
                  ),

                const SizedBox(height: 30),

                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authState.isLoading
                        ? null
                        : _otpSent
                        ? _verifyOtp
                        : _sendOtp,
                    child: authState.isLoading
                        ? const CircularProgressIndicator()
                        : Text(_otpSent ? "Verify OTP" : "Send OTP"),
                  ),
                ),

                if (_otpSent) ...[
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: _resendTimer == 0 ? _sendOtp : null,
                    child: Text(
                      _resendTimer == 0
                          ? "Resend OTP"
                          : "Resend in $_resendTimer s",
                      style: TextStyle(color: scheme.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Phone Input
class _PhoneInput extends StatelessWidget {
  final TextEditingController controller;

  const _PhoneInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        hintText: "Phone Number",
        prefixIcon: const Icon(Icons.phone_outlined),
        filled: true,
        fillColor: scheme.surfaceVariant.withOpacity(.3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// OTP Box
class OtpDigitField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onChanged;

  const OtpDigitField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  State<OtpDigitField> createState() => _OtpDigitFieldState();
}

class _OtpDigitFieldState extends State<OtpDigitField>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  bool _focused = false;

  @override
  void initState() {
    super.initState();

    widget.focusNode.addListener(() {
      setState(() {
        _focused = widget.focusNode.hasFocus;
      });
    });

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: SizedBox(
        width: 48,
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 1,
          onChanged: (v) {
            if (v.isNotEmpty) {
              _scaleController.forward().then((_) {
                _scaleController.reverse();
              });
            }

            widget.onChanged(v);
          },
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: "",
            filled: true,
            fillColor: scheme.surfaceVariant.withOpacity(.35),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.primary, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _focused
                    ? scheme.primary
                    : scheme.outline.withOpacity(.25),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShakeWidget extends StatefulWidget {
  final Widget child;

  const ShakeWidget({super.key, required this.child});

  @override
  ShakeWidgetState createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _animation = Tween<double>(
      begin: 0,
      end: 12,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticIn));
  }

  void shake() {
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
