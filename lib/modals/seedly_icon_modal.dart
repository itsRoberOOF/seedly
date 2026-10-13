import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/seedly_image_picker.dart';
import '../services/seedly_projects.dart';
import '../theme/seedly_theme.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_icon_tile.dart';
import '../widgets/seedly_modal.dart';
import '../widgets/seedly_option_card.dart';

/// What "Modal imagen" completes with.
sealed class SeedlyAvatarChoice {
  const SeedlyAvatarChoice();
}

final class SeedlyIconChoice extends SeedlyAvatarChoice {
  const SeedlyIconChoice(this.icon);

  final SeedlyProjectIcon icon;
}

final class SeedlyPhotoChoice extends SeedlyAvatarChoice {
  const SeedlyPhotoChoice(this.photo);

  /// A small JPEG from the gallery.
  final Uint8List photo;
}

/// Figma "Modal imagen": a photo from the gallery or one of the category
/// icons. Completes with the choice, or null when closed.
Future<SeedlyAvatarChoice?> showSeedlyIconModal(
  BuildContext context, {
  required SeedlyImagePicker picker,
  SeedlyProjectIcon? selected,
}) {
  return showSeedlyModal<SeedlyAvatarChoice>(
    context,
    childScrolls: true,
    builder: (context) => _IconModal(picker: picker, selected: selected),
  );
}

class _IconModal extends StatelessWidget {
  const _IconModal({required this.picker, this.selected});

  final SeedlyImagePicker picker;
  final SeedlyProjectIcon? selected;

  static const _columns = 4;
  static const _gap = 20.0;

  /// The title and the gallery card come before the icon rows.
  static const _headerItems = 2;

  Future<void> _pickPhoto(BuildContext context) async {
    try {
      final photo = await picker.pickFromGallery();
      if (photo != null && context.mounted) {
        Navigator.of(context).pop(SeedlyPhotoChoice(photo));
      }
    } on SeedlyImagePickerException catch (error) {
      if (!context.mounted) return;
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'No se pudo cargar la imagen',
        message: error.message,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final icons = SeedlyProjectIcon.choices;
    final rows = (icons.length / _columns).ceil();
    // Only the rows on screen get built while scrolling the catalogue.
    return ListView.builder(
      padding: SeedlyModal.scrollPadding(
        const EdgeInsets.fromLTRB(24, 24, 24, 20),
      ),
      itemCount: _headerItems + rows,
      itemBuilder: (context, index) => switch (index) {
        0 => Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Text(
            'Seleccionar imagen',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              height: 28 / 18,
              fontWeight: FontWeight.w600,
              color: SeedlyPalette.neutral[850],
            ),
          ),
        ),
        1 => Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: SeedlyOptionCard(
            icon: 'assets/images/icon_gallery.svg',
            title: 'Elegir imagen',
            description: 'Desde tu galería',
            onTap: () => _pickPhoto(context),
          ),
        ),
        _ => _row(context, icons, index - _headerItems, rows),
      },
    );
  }

  Widget _row(
    BuildContext context,
    List<SeedlyProjectIcon> icons,
    int row,
    int rows,
  ) {
    final start = row * _columns;
    return Padding(
      padding: EdgeInsets.only(bottom: row == rows - 1 ? 0 : _gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _gap,
        children: [
          for (var i = start; i < start + _columns; i++)
            Expanded(
              // Empty slots keep the last row's tiles in their columns.
              child: i < icons.length
                  ? SeedlyIconTile(
                      icon: icons[i].asset,
                      label: icons[i].label,
                      selected: icons[i] == selected,
                      onTap: () =>
                          Navigator.of(context).pop(SeedlyIconChoice(icons[i])),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
