import 'package:flutter/material.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

class StudyStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const StudyStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: AppTypography.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: AppTypography.heading2),
        ],
      ),
    );
  }
}
