import 'package:flutter/material.dart';

import '../theme/seedly_theme.dart';

/// Figma "Time picker": hour, minute and AM/PM wheels. The middle row sits on
/// a white card in bold green; the rows around it fade to grey.
class SeedlyTimePicker extends StatefulWidget {
  const SeedlyTimePicker({
    super.key,
    required this.minutes,
    required this.onChanged,
  });

  /// The time shown, in minutes after midnight.
  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  State<SeedlyTimePicker> createState() => _SeedlyTimePickerState();
}

class _SeedlyTimePickerState extends State<SeedlyTimePicker> {
  static const _rowHeight = 62.0;

  /// 0-11 for 12, 1, 2 … 11.
  late int _hour = (widget.minutes ~/ 60) % 12;
  late int _minute = widget.minutes % 60;
  late bool _pm = widget.minutes >= 12 * 60;

  late final _hours = FixedExtentScrollController(initialItem: _hour);
  late final _minutes = FixedExtentScrollController(initialItem: _minute);
  late final _periods = FixedExtentScrollController(initialItem: _pm ? 1 : 0);

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    _periods.dispose();
    super.dispose();
  }

  void _report() =>
      widget.onChanged((_pm ? 12 * 60 : 0) + _hour * 60 + _minute);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _rowHeight * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The selected row's card, as in Figma.
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: SeedlyPalette.neutral[50],
              borderRadius: BorderRadius.circular(SeedlyMetrics.radii['md']!),
              border: Border.all(color: SeedlyPalette.border),
              boxShadow: SeedlyShadows.card,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _Wheel(
                  label: 'Hora',
                  controller: _hours,
                  count: 12,
                  looping: true,
                  selected: _hour,
                  text: (i) => (i == 0 ? 12 : i).toString().padLeft(2, '0'),
                  onChanged: (i) {
                    setState(() => _hour = i);
                    _report();
                  },
                ),
                _Wheel(
                  label: 'Minutos',
                  controller: _minutes,
                  count: 60,
                  looping: true,
                  selected: _minute,
                  text: (i) => i.toString().padLeft(2, '0'),
                  onChanged: (i) {
                    setState(() => _minute = i);
                    _report();
                  },
                ),
                _Wheel(
                  label: 'AM o PM',
                  controller: _periods,
                  count: 2,
                  looping: false,
                  selected: _pm ? 1 : 0,
                  text: (i) => i == 0 ? 'AM' : 'PM',
                  onChanged: (i) {
                    setState(() => _pm = i == 1);
                    _report();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.label,
    required this.controller,
    required this.count,
    required this.looping,
    required this.selected,
    required this.text,
    required this.onChanged,
  });

  final String label;
  final FixedExtentScrollController controller;
  final int count;
  final bool looping;
  final int selected;
  final String Function(int index) text;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(int index) {
      final active = index == selected;
      return Center(
        child: Text(
          text(index),
          style: TextStyle(
            fontSize: active ? 40 : 32,
            height: active ? 48 / 40 : 38 / 32,
            fontWeight: FontWeight.w700,
            color: active
                ? SeedlyPalette.primary[500]
                : SeedlyPalette.neutral[500],
          ),
        ),
      );
    }

    return Expanded(
      child: Semantics(
        label: label,
        value: text(selected),
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: _SeedlyTimePickerState._rowHeight,
          // Nearly flat, like Figma's rows.
          diameterRatio: 3,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (index) => onChanged(index % count),
          childDelegate: looping
              ? ListWheelChildLoopingListDelegate(
                  children: [for (var i = 0; i < count; i++) item(i)],
                )
              : ListWheelChildListDelegate(
                  children: [for (var i = 0; i < count; i++) item(i)],
                ),
        ),
      ),
    );
  }
}
