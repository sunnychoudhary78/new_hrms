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
    final iconColor = scheme.onSurface;
    final scaffold = Scaffold.maybeOf(context);
    final showDrawer = !showBack && (scaffold?.hasDrawer ?? false);

    Widget? leading;
    if (showBack) {
      leading = IconButton(
        tooltip: 'Back',
        color: iconColor,
        icon: Icon(
          isIOS ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_rounded,
          color: iconColor,
        ),
        padding: isIOS ? const EdgeInsetsDirectional.only(start: 10) : null,
        onPressed: () => Navigator.of(context).maybePop(),
      );
    } else if (showDrawer) {
      leading = IconButton(
        tooltip: 'Menu',
        color: iconColor,
        icon: Icon(Icons.menu_rounded, color: iconColor),
        onPressed: () => scaffold!.openDrawer(),
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: AppBar(
          elevation: 0,
          centerTitle: isIOS,
          automaticallyImplyLeading: false,
          backgroundColor: scheme.surface.withValues(alpha: 0.94),
          foregroundColor: iconColor,
          iconTheme: IconThemeData(color: iconColor, size: 24),
          actionsIconTheme: IconThemeData(color: iconColor, size: 24),
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          title: Text(
            title,
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.w600,
              letterSpacing: -.2,
            ),
          ),
          leading: leading,
          actions: actions,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: scheme.outline.withValues(alpha: .15),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
