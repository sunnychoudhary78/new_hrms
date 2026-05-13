import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ReasonInput extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const ReasonInput({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final radius = isIOS ? 12.0 : 14.0;

    return TextField(
      maxLines: 4,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,

      decoration: InputDecoration(
        labelText: "Reason",
        hintText: "Briefly explain your leave...",
        prefixIcon: const Icon(Icons.notes),
        alignLabelWithHint: true,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withOpacity(isIOS ? 0.35 : 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outline.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.primary, width: isIOS ? 1 : 1.5),
        ),
      ),

      onChanged: onChanged,
    );
  }
}
