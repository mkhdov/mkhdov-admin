import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;
    String label = status.toLowerCase();

    switch (label) {
      case 'published':
        textColor = AppColors.success;
        bgColor = AppColors.successBg;
        label = 'Published';
        break;
      case 'draft':
        textColor = AppColors.textMuted;
        bgColor = AppColors.textMuted.withValues(alpha: 0.1);
        label = 'Draft';
        break;
      case 'open':
        textColor = const Color(0xFF047857);
        bgColor = const Color(0x1A10B981); // 0.1 opacity
        label = 'Open';
        break;
      case 'resolved':
        textColor = const Color(0xFF7C3AED);
        bgColor = const Color(0x1A7C3AED);
        label = 'Resolved';
        break;
      default:
        textColor = AppColors.textBody;
        bgColor = AppColors.borderLight;
        label = label.isEmpty ? 'Unknown' : '${label[0].toUpperCase()}${label.substring(1)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
            ),
      ),
    );
  }
}
