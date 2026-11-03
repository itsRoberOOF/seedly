import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/seedly_project.dart';
import '../theme/seedly_theme.dart';
import '../utils/seedly_dates.dart';

/// The yellow tag over a project's name: "1 día para la entrega", shown only
/// while the project is not done and its end is a week away or less (or
/// already past). Null when there is nothing to warn about.
String? seedlyDeadlineLabel(SeedlyProject project, DateTime today) {
  final end = project.endDate;
  if (end == null || project.isComplete) return null;
  final days = SeedlyDates.day(end).difference(SeedlyDates.day(today)).inDays;
  if (days < 0) return 'Entrega vencida';
  if (days == 0) return 'Hoy es la entrega';
  if (days > 7) return null;
  return days == 1 ? '1 día para la entrega' : '$days días para la entrega';
}

/// Figma "Tag" (warning): a yellow pill with a triangle and [label].
class SeedlyDeadlineTag extends StatelessWidget {
  const SeedlyDeadlineTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: SeedlyPalette.warning[600],
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          SvgPicture.asset(
            'assets/images/icon_warning_triangle.svg',
            width: 16,
            height: 16,
          ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                height: 14 / 10,
                fontWeight: FontWeight.w600,
                color: SeedlyPalette.neutral[850],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
