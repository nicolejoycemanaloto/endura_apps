import 'package:flutter/cupertino.dart';
import 'package:endura/core/theme/app_theme.dart';

/// Small stat display widget: icon + label + value + optional unit.
class StatTile extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final String? unit;
  final Color? valueColor;

  const StatTile({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(height: 2),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppTheme.textColor(context),
                height: 1.0,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  unit!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}


