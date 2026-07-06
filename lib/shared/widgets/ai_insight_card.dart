import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';


class AIInsightCard extends StatelessWidget {
  final String content;
  final String title;
  final IconData icon;

  const AIInsightCard({
    super.key,
    required this.content,
    this.title = "AI Security Insights",
    this.icon = Icons.auto_awesome_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1B233E), // Custom navy background matching design system
        borderRadius: AppBorderRadius.lgBorder,
        border: Border.all(
          color: const Color(0xFF2E3B68),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.amber, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            content,
            style: const TextStyle(
              color: Color(0xFFC5CAE9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
