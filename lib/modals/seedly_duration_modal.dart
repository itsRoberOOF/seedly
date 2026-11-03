import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/seedly_watering.dart';
import '../theme/seedly_theme.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_modal.dart';

/// "Tiempo personalizado" de Riego: una rueda de minutos, de
/// [SeedlyWatering.minMinutes] a [SeedlyWatering.maxMinutes], con Cancelar y
/// Confirmar como en "Modal hora". Completa con los minutos elegidos, o null
/// si se cancela.
Future<int?> showSeedlyDurationModal(BuildContext context, {int? initial}) {
  final minutes = (initial ?? SeedlyWatering.defaultMinutes).clamp(
    SeedlyWatering.minMinutes,
    SeedlyWatering.maxMinutes,
  );
  return showSeedlyModal<int>(
    context,
    showClose: false,
    builder: (context) => _DurationModal(initial: minutes),
  );
}

class _DurationModal extends StatefulWidget {
  const _DurationModal({required this.initial});

  final int initial;

  @override
  State<_DurationModal> createState() => _DurationModalState();
}

class _DurationModalState extends State<_DurationModal> {
  /// La misma altura de fila que la rueda de "Modal hora".
  static const _rowHeight = 62.0;

  late int _minutes = widget.initial;
  late final _wheel = FixedExtentScrollController(
    initialItem: _minutes - SeedlyWatering.minMinutes,
  );

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 48,
      children: [
        Text(
          'Tiempo personalizado',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            height: 28 / 18,
            fontWeight: FontWeight.w600,
            color: SeedlyPalette.neutral[850],
          ),
        ),
        SizedBox(
          height: _rowHeight * 3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // La tarjeta de la fila elegida, como en el selector de hora.
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: SeedlyPalette.neutral[50],
                  borderRadius: BorderRadius.circular(
                    SeedlyMetrics.radii['md']!,
                  ),
                  border: Border.all(color: SeedlyPalette.border),
                  boxShadow: SeedlyShadows.card,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 120, child: _minutesWheel()),
                  Text(
                    'min',
                    style: TextStyle(
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: SeedlyPalette.primary[500],
                    ),
                  ),
                ],
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
                onPressed: () => Navigator.of(context).pop(_minutes),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _minutesWheel() {
    const count = SeedlyWatering.maxMinutes - SeedlyWatering.minMinutes + 1;
    return Semantics(
      label: 'Minutos',
      value: '$_minutes min',
      child: ListWheelScrollView.useDelegate(
        controller: _wheel,
        itemExtent: _rowHeight,
        // Casi plana, como las filas de Figma.
        diameterRatio: 3,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) =>
            setState(() => _minutes = index + SeedlyWatering.minMinutes),
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, index) {
            final minutes = index + SeedlyWatering.minMinutes;
            final active = minutes == _minutes;
            return Center(
              child: Text(
                '$minutes',
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
          },
        ),
      ),
    );
  }
}
