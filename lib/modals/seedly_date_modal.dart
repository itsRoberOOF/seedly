import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';
import '../utils/seedly_dates.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_date_picker.dart';
import '../widgets/seedly_modal.dart';
import '../widgets/seedly_tag.dart';

/// Figma "Modal fecha": the calendar, quick-date tags and Cancelar /
/// Confirmar. Completes with the confirmed day, or null when cancelled.
Future<DateTime?> showSeedlyDateModal(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? today,
}) {
  return showSeedlyModal<DateTime>(
    context,
    showClose: false,
    builder: (context) =>
        _DateModal(initial: initial, firstDate: firstDate, today: today),
  );
}

class _DateModal extends StatefulWidget {
  const _DateModal({this.initial, this.firstDate, this.today});

  final DateTime? initial;
  final DateTime? firstDate;
  final DateTime? today;

  @override
  State<_DateModal> createState() => _DateModalState();
}

class _DateModalState extends State<_DateModal> {
  late final DateTime _today = SeedlyDates.day(widget.today ?? DateTime.now());
  late DateTime? _selected = widget.initial;

  bool _allowed(DateTime day) =>
      widget.firstDate == null ||
      !day.isBefore(SeedlyDates.day(widget.firstDate!));

  List<(String, DateTime)> get _quickDates => SeedlyDates.quickDates(_today);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 32,
      children: [
        SeedlyDatePicker(
          selected: _selected,
          firstDate: widget.firstDate,
          today: _today,
          onChanged: (day) => setState(() => _selected = day),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            spacing: 10,
            children: [
              for (final (label, day) in _quickDates)
                SeedlyTag(
                  label: label,
                  onTap: _allowed(day)
                      ? () => setState(() => _selected = day)
                      : null,
                ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: SeedlyButton(
                label: 'Cancelar',
                variant: SeedlyButtonVariant.text,
                size: SeedlyButtonSize.large,
                foreground: SeedlyPalette.neutral[700],
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              flex: 3,
              child: SeedlyButton(
                label: 'Confirmar',
                size: SeedlyButtonSize.large,
                expand: true,
                leading: SvgPicture.asset(
                  'assets/images/icon_save.svg',
                  width: 24,
                  height: 24,
                ),
                onPressed: _selected == null
                    ? null
                    : () => Navigator.of(context).pop(_selected),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
