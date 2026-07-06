import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

enum SafetyStatus { safe, caution, danger }

class SafetyStatusBadge extends StatelessWidget {
  final SafetyStatus status;

  const SafetyStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case SafetyStatus.safe:
        color = AppColors.success;
        label = "Safe";
        icon = Icons.check_circle_outline_rounded;
        break;
      case SafetyStatus.caution:
        color = AppColors.warning;
        label = "Caution";
        icon = Icons.warning_amber_rounded;
        break;
      case SafetyStatus.danger:
        color = AppColors.error;
        label = "Danger";
        icon = Icons.error_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppBorderRadius.roundBorder,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
