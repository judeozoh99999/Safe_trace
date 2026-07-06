import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

enum ButtonType { primary, secondary, ghost, danger }

class SafeTraceButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final IconData? icon;
  final bool isLoading;

  const SafeTraceButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.primary,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color buttonColor;
    Color textColor;
    BorderSide borderSide = BorderSide.none;

    switch (type) {
      case ButtonType.primary:
        buttonColor = AppColors.primary;
        textColor = AppColors.white;
        break;
      case ButtonType.secondary:
        buttonColor = isDark ? AppColors.buttonDark : AppColors.buttonLight;
        textColor = AppColors.white;
        break;
      case ButtonType.ghost:
        buttonColor = Colors.transparent;
        textColor = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
        borderSide = BorderSide(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 1.5,
        );
        break;
      case ButtonType.danger:
        buttonColor = AppColors.error;
        textColor = AppColors.white;
        break;
    }

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: AppBorderRadius.xlBorder,
        boxShadow: type == ButtonType.primary ? AppShadows.glowPrimary : null,
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.xlBorder,
            side: borderSide,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
