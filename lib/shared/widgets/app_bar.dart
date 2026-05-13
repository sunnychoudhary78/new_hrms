import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final List<Widget>? actions;

  const AppAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final blurSigma = isIOS ? 10.0 : 12.0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: AppBar(
          elevation: 0,
          centerTitle: isIOS,

          /// TRUE glass background
          backgroundColor: scheme.surface.withOpacity(0.55),

          foregroundColor: scheme.onSurface,

          scrolledUnderElevation: 0,

          surfaceTintColor: Colors.transparent,

          shadowColor: Colors.transparent,

          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: -.2,
            ),
          ),

          leading: showBack
              ? IconButton(
                  icon: Icon(
                    isIOS
                        ? Icons.arrow_back_ios_new_rounded
                        : Icons.arrow_back_rounded,
                  ),
                  padding: isIOS
                      ? const EdgeInsetsDirectional.only(start: 10)
                      : null,
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : null,

          actions: actions,

          /// Glass border highlight
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: scheme.outline.withOpacity(.15)),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
