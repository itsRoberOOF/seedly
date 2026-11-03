import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_modal.dart';

/// Figma "Modal eliminar proyecto" / "Modal eliminar tarea": a blob with a
/// red trash can, what is about to be lost, and Cancelar / Eliminar.
/// Completes with true only when the person confirms.
Future<bool> showSeedlyDeleteModal(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showSeedlyModal<bool>(
    context,
    showClose: false,
    // Figma's 40px sides.
    padding: const EdgeInsets.fromLTRB(40, 40, 40, 20),
    builder: (context) => _DeleteModal(title: title, message: message),
  );
  return confirmed ?? false;
}

class _DeleteModal extends StatelessWidget {
  const _DeleteModal({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              children: [
                SvgPicture.asset(
                  'assets/images/modal_blob_danger.svg',
                  width: 200,
                  height: 200,
                ),
                Positioned(
                  left: 50,
                  top: 50,
                  child: SvgPicture.asset(
                    'assets/images/modal_trash.svg',
                    width: 100,
                    height: 100,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            height: 34 / 28,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: SeedlyPalette.neutral[850],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            height: 28 / 18,
            fontWeight: FontWeight.w500,
            color: SeedlyPalette.neutral[700],
          ),
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Expanded(
              child: SeedlyButton(
                label: 'Cancelar',
                variant: SeedlyButtonVariant.text,
                size: SeedlyButtonSize.large,
                foreground: SeedlyPalette.neutral[700],
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            Expanded(
              child: SeedlyButton(
                label: 'Eliminar',
                size: SeedlyButtonSize.large,
                expand: true,
                color: SeedlyPalette.danger[600],
                leading: SvgPicture.asset(
                  'assets/images/icon_trash.svg',
                  width: 24,
                  height: 24,
                ),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
