import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class SafeTraceAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final bool transparent;

  const SafeTraceAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.transparent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: transparent
          ? Colors.transparent
          : (isDark ? AppColors.backgroundDark : AppColors.backgroundLight),
      leading: leading ??
          (showBackButton && Navigator.canPop(context)
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                )
              : null),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
