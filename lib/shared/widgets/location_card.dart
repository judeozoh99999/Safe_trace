import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class LocationCard extends StatefulWidget {
  final String locationName;
  final String timestamp;
  final String? note;
  final String? aiAdvice;
  final VoidCallback? onDelete;
  final bool initialExpanded;

  const LocationCard({
    super.key,
    required this.locationName,
    required this.timestamp,
    this.note,
    this.aiAdvice,
    this.onDelete,
    this.initialExpanded = false,
  });

  @override
  State<LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<LocationCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: UniqueKey(),
      direction: widget.onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: AppBorderRadius.mdBorder,
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) {
        if (widget.onDelete != null) widget.onDelete!();
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mdBorder,
          side: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 1.5,
          ),
        ),
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.timestamp,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.note != null || widget.aiAdvice != null)
                    IconButton(
                      icon: Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                        size: 26,
                      ),
                      onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    ),
                ],
              ),
              if (_isExpanded) ...[
                if (widget.note != null && widget.note!.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Divider(height: 1),
                  ),
                  Text(
                    "Log Note",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.note!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary,
                    ),
                  ),
                ],
                if (widget.aiAdvice != null && widget.aiAdvice!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B233E), // Custom Deep Blue
                      borderRadius: AppBorderRadius.mdBorder,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 18),
                            SizedBox(width: AppSpacing.sm),
                            Text(
                              "AI Safety Advice",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          widget.aiAdvice!,
                          style: const TextStyle(
                            color: Color(0xFFC5CAE9),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
