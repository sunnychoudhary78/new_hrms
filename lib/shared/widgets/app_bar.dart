import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const AppAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final scaffold = Scaffold.maybeOf(context);
    final showDrawer = !showBack && (scaffold?.hasDrawer ?? false);
    final scheme = Theme.of(context).colorScheme;

    Widget? leading;
    if (showBack) {
      leading = IconButton(
        tooltip: 'Back',
        icon: Icon(
          isIOS ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_rounded,
        ),
        padding: isIOS ? const EdgeInsetsDirectional.only(start: 10) : null,
        onPressed: () => Navigator.of(context).maybePop(),
      );
    } else if (showDrawer) {
      leading = IconButton(
        tooltip: 'Menu',
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => scaffold!.openDrawer(),
      );
    }

    return AppBar(
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      backgroundColor: scheme.surfaceContainerLowest,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleSpacing: leading == null ? AppSpacing.md : 0,
      title: Text(
        title,
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: -.2,
        ),
      ),
      leading: leading,
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );
}
