import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// Figma "Input-Button": looks like an input but opens a picker when tapped,
/// such as the date fields. [helper] is the small caption above the value
/// ("INICIO"); [label] goes above the box like an input's label.
class SeedlyInputButton extends StatelessWidget {
  const SeedlyInputButton({
    super.key,
    required this.placeholder,
    required this.onTap,
    this.value,
    this.label,
    this.helper,
    this.icon = 'assets/images/icon_calendar.svg',
    this.error = false,
    this.enabled = true,
  });

  /// Greys the field out and ignores taps, e.g. until a prerequisite is set.
  final bool enabled;

  final String placeholder;
  final VoidCallback? onTap;

  /// Shown instead of [placeholder] once something is chosen.
  final String? value;
  final String? label;
  final String? helper;
  final String icon;

  /// Turns the border danger-600, like an invalid input.
  final bool error;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SeedlyMetrics.radii['lg']!);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: enabled ? SeedlyShadows.card : null,
      ),
      child: Material(
        color: enabled ? SeedlyPalette.neutral[50] : SeedlyPalette.neutral[150],
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: error ? SeedlyPalette.danger[600]! : SeedlyPalette.border,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 10,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      if (helper != null)
                        Text(
                          helper!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            fontWeight: FontWeight.w500,
                            color: SeedlyPalette.neutral[700],
                          ),
                        ),
                      Text(
                        value ?? placeholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          height: 24 / 16,
                          color: value == null
                              ? SeedlyPalette.neutral[600]
                              : SeedlyPalette.neutral[850],
                        ),
                      ),
                    ],
                  ),
                ),
                Opacity(
                  opacity: enabled ? 1 : 0.4,
                  child: SvgPicture.asset(icon, width: 24, height: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final field = Semantics(
      button: true,
      label: [label, helper, value ?? placeholder].nonNulls.join(', '),
      excludeSemantics: true,
      child: box,
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          label!,
          style: TextStyle(
            fontSize: 16,
            height: 24 / 16,
            fontWeight: FontWeight.w500,
            color: SeedlyPalette.neutral[850],
          ),
        ),
        field,
      ],
    );
  }
}
