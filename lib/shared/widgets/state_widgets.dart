import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'custom_buttons.dart';

class LoadingSkeleton extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const LoadingSkeleton({
    super.key,
    this.height = 20.0,
    this.width = double.infinity,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.grey[300],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const SizedBox.shrink(),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.actionText,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onActionPressed != null) ...[
            const SizedBox(height: AppSpacing.xl),
            SafeTraceButton(
              text: actionText!,
              onPressed: onActionPressed,
              type: ButtonType.ghost,
            ),
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "Something went wrong",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          SafeTraceButton(
            text: "Retry",
            onPressed: onRetry,
            type: ButtonType.primary,
          ),
        ],
      ),
    );
  }
}
