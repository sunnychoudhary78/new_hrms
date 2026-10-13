import 'package:flutter/material.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';

class SubmitButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const SubmitButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppPrimaryButton(
      label: 'Submit',
      isLoading: isLoading,
      onPressed: onPressed,
      icon: Icons.send_rounded,
    );
  }
}
