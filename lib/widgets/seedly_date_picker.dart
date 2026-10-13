import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';
import '../utils/seedly_dates.dart';

/// Figma "Date Picker" calendar: a month grid, Sunday first, where the
/// selected day is filled green and today is outlined. Days before
/// [firstDate] can't be picked.
class SeedlyDatePicker extends StatefulWidget {
  const SeedlyDatePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.firstDate,
    this.today,
  });

  final DateTime? selected;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;

  /// Defaults to the current day; tests pin it.
  final DateTime? today;

  @override
  State<SeedlyDatePicker> createState() => _SeedlyDatePickerState();
}

class _SeedlyDatePickerState extends State<SeedlyDatePicker> {
  late DateTime _month = _monthOf(
    widget.selected ?? widget.firstDate ?? _today,
  );

  DateTime get _today => SeedlyDates.day(widget.today ?? DateTime.now());

  static DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

  @override
  void didUpdateWidget(SeedlyDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow a selection made outside the grid, like the quick-date tags.
    final selected = widget.selected;
    if (selected != null &&
        selected != oldWidget.selected &&
        _monthOf(selected) != _month) {
      _month = _monthOf(selected);
    }
  }

  bool get _canGoBack {
    final first = widget.firstDate;
    return first == null || _month.isAfter(_monthOf(first));
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    // Six full weeks, starting on the Sunday on or before the 1st.
    final start = _month.subtract(Duration(days: _month.weekday % 7));
    final days = [
      for (var i = 0; i < 42; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    final first = widget.firstDate == null
        ? null
        : SeedlyDates.day(widget.firstDate!);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SeedlyPalette.neutral[50],
        borderRadius: BorderRadius.circular(SeedlyMetrics.radii['xl']!),
        border: Border.all(color: SeedlyPalette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 24,
        children: [
          Row(
            children: [
              _MonthArrow(
                tooltip: 'Mes anterior',
                onPressed: _canGoBack ? () => _shiftMonth(-1) : null,
              ),
              Expanded(
                child: Text(
                  SeedlyDates.monthYear(_month),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    height: 28 / 18,
                    fontWeight: FontWeight.w600,
                    color: SeedlyPalette.neutral[850],
                  ),
                ),
              ),
              _MonthArrow(
                tooltip: 'Mes siguiente',
                flip: true,
                onPressed: () => _shiftMonth(1),
              ),
            ],
          ),
          Column(
            spacing: 8,
            children: [
              Row(
                children: [
                  for (final weekday in SeedlyDates.weekdays)
                    Expanded(
                      child: Text(
                        weekday,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          fontWeight: FontWeight.w500,
                          color: SeedlyPalette.primary[500],
                        ),
                      ),
                    ),
                ],
              ),
              for (var week = 0; week < 6; week++)
                Row(
                  children: [
                    for (final day in days.skip(week * 7).take(7))
                      Expanded(
                        child: _DayCell(
                          day: day,
                          inMonth: day.month == _month.month,
                          selected:
                              widget.selected != null &&
                              SeedlyDates.sameDay(day, widget.selected!),
                          today: SeedlyDates.sameDay(day, _today),
                          onTap: first != null && day.isBefore(first)
                              ? null
                              : () => widget.onChanged(day),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.tooltip,
    required this.onPressed,
    this.flip = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Transform.flip(
        flipX: flip,
        child: SvgPicture.asset(
          'assets/images/icon_nav_left.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            onPressed == null
                ? SeedlyPalette.neutral[400]!
                : SeedlyPalette.primary[500]!,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brand = SeedlyPalette.primary[500]!;
    final textColor = selected
        ? SeedlyPalette.neutral[50]!
        : onTap == null
        ? SeedlyPalette.neutral[500]!
        : inMonth
        ? SeedlyPalette.neutral[850]!
        : SeedlyPalette.neutral[600]!;
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: SeedlyDates.short(day),
      excludeSemantics: true,
      child: Center(
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: Container(
            width: 40,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? brand
                  : today
                  ? SeedlyPalette.primary[50]
                  : null,
              border: today && !selected ? Border.all(color: brand) : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(fontSize: 14, height: 20 / 14, color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}
