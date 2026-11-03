import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_modal.dart';

/// Figma "Modal eliminar tarea" and "Modal eliminar proyecto": the red
/// confirmation modal. An [illustration] over a pale red blob, a title, a
/// message, "Cancelar" and a red confirm button.
///
/// Completes with true only when the person confirms; "Cancelar", the
/// barrier and a swipe down all complete with false.
///
/// [illustration] is a 100px SVG; [confirmIcon] is drawn white in the confirm
/// button, as Figma's trash is. By default the modal is red; [confirmColor]
/// and [blobColor] tint the button and the blob behind the illustration for a
/// non-destructive variant, such as the green "terminar riego".
Future<bool> showSeedlyConfirmModal(
  BuildContext context, {
  required String illustration,
  required String title,
  required String message,
  required String confirmLabel,
  String? confirmIcon,
  String cancelLabel = 'Cancelar',
  Color? confirmColor,
  Color? blobColor,
  Color? illustrationColor,
}) async {
  final confirmed = await showSeedlyModal<bool>(
    context,
    showClose: false,
    padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
    builder: (context) => SeedlyConfirmContent(
      illustration: illustration,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      confirmIcon: confirmIcon,
      cancelLabel: cancelLabel,
      confirmColor: confirmColor,
      blobColor: blobColor,
      illustrationColor: illustrationColor,
    ),
  );
  return confirmed ?? false;
}

/// The content slot of [showSeedlyConfirmModal].
class SeedlyConfirmContent extends StatelessWidget {
  const SeedlyConfirmContent({
    super.key,
    required this.illustration,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.confirmIcon,
    this.cancelLabel = 'Cancelar',
    this.confirmColor,
    this.blobColor,
    this.illustrationColor,
  });

  final String illustration;
  final String title;
  final String message;
  final String confirmLabel;
  final String? confirmIcon;
  final String cancelLabel;

  /// The confirm button's colour and the blob behind the illustration; both
  /// default to Figma's red. [illustrationColor] recolours the illustration
  /// SVG; null keeps its own colours.
  final Color? confirmColor;
  final Color? blobColor;
  final Color? illustrationColor;

  /// Phones shorter than this get a smaller illustration and tighter gaps,
  /// so the buttons are on screen without scrolling the modal.
  static const compactHeight = 700.0;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < compactHeight;
    // Figma: a 200px blob with the 100px icon centred on it.
    final blob = compact ? 140.0 : 200.0;
    final gap = compact ? 24.0 : 48.0;
    final confirmColor = this.confirmColor ?? SeedlyPalette.danger[600]!;
    final blobColor = this.blobColor ?? SeedlyPalette.danger[200]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox.square(
            dimension: blob,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SvgPicture.asset(
                  'assets/images/modal_danger_blob.svg',
                  width: blob,
                  height: blob,
                  excludeFromSemantics: true,
                  colorFilter: ColorFilter.mode(blobColor, BlendMode.srcIn),
                ),
                SvgPicture.asset(
                  illustration,
                  width: blob / 2,
                  height: blob / 2,
                  excludeFromSemantics: true,
                  colorFilter: illustrationColor == null
                      ? null
                      : ColorFilter.mode(illustrationColor!, BlendMode.srcIn),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: gap),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              height: 34 / 28,
              fontWeight: FontWeight.w600,
              // Figma's 2px, as in the delete modals' titles.
              letterSpacing: 2,
              color: SeedlyPalette.neutral[850],
            ),
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
        SizedBox(height: gap),
        Row(
          spacing: 8,
          children: [
            // Confirm gets the wider share: its label and icon are longer
            // than "Cancelar", and "Cerrar sesión" was cut on 360px phones.
            Expanded(
              flex: 2,
              child: SeedlyButton(
                label: cancelLabel,
                variant: SeedlyButtonVariant.text,
                size: SeedlyButtonSize.large,
                foreground: SeedlyPalette.neutral[700],
                expand: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            Expanded(
              flex: 3,
              child: SeedlyButton(
                label: confirmLabel,
                size: SeedlyButtonSize.large,
                color: confirmColor,
                expand: true,
                leading: confirmIcon == null
                    ? null
                    : SvgPicture.asset(
                        confirmIcon!,
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
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
