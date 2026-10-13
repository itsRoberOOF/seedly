import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_modal.dart';
import '../widgets/seedly_time_picker.dart';

/// Figma "Modal hora": the time wheels with Cancelar / Confirmar. Completes
/// with minutes after midnight, or null when cancelled.
Future<int?> showSeedlyTimeModal(BuildContext context, {int? initial}) {
  return showSeedlyModal<int>(
    context,
    showClose: false,
    builder: (context) => _TimeModal(initial: initial ?? 9 * 60),
  );
}

class _TimeModal extends StatefulWidget {
  const _TimeModal({required this.initial});

  final int initial;

  @override
  State<_TimeModal> createState() => _TimeModalState();
}

class _TimeModalState extends State<_TimeModal> {
  late int _minutes = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 48,
      children: [
        Text(
          'Seleccionar hora',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            height: 28 / 18,
            fontWeight: FontWeight.w600,
            color: SeedlyPalette.neutral[850],
          ),
        ),
        SeedlyTimePicker(
          minutes: _minutes,
          onChanged: (minutes) => setState(() => _minutes = minutes),
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
}
