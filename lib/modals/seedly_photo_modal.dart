import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/seedly_image_picker.dart';
import '../theme/seedly_theme.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_modal.dart';
import '../widgets/seedly_option_card.dart';

/// What the profile photo modal completes with.
sealed class SeedlyProfilePhotoChoice {
  const SeedlyProfilePhotoChoice();
}

final class SeedlyPhotoPicked extends SeedlyProfilePhotoChoice {
  const SeedlyPhotoPicked(this.photo);

  /// A small JPEG from the gallery.
  final Uint8List photo;
}

/// Go back to showing the person's initials.
final class SeedlyPhotoRemoved extends SeedlyProfilePhotoChoice {
  const SeedlyPhotoRemoved();
}

/// The profile photo choices in the style of Figma's "Modal imagen": a photo
/// from the gallery and, when there is one, removing it. Completes with the
/// choice, or null when closed.
Future<SeedlyProfilePhotoChoice?> showSeedlyPhotoModal(
  BuildContext context, {
  required SeedlyImagePicker picker,
  required bool hasPhoto,
}) {
  return showSeedlyModal<SeedlyProfilePhotoChoice>(
    context,
    builder: (context) => _PhotoModal(picker: picker, hasPhoto: hasPhoto),
  );
}

class _PhotoModal extends StatelessWidget {
  const _PhotoModal({required this.picker, required this.hasPhoto});

  final SeedlyImagePicker picker;
  final bool hasPhoto;

  Future<void> _pickPhoto(BuildContext context) async {
    try {
      final photo = await picker.pickFromGallery();
      if (photo != null && context.mounted) {
        Navigator.of(context).pop(SeedlyPhotoPicked(photo));
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Foto de perfil',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            height: 28 / 18,
            fontWeight: FontWeight.w600,
            color: SeedlyPalette.neutral[850],
          ),
        ),
        const SizedBox(height: 32),
        SeedlyOptionCard(
          icon: 'assets/images/icon_gallery.svg',
          title: 'Elegir imagen',
          description: 'Desde tu galería',
          onTap: () => _pickPhoto(context),
        ),
        if (hasPhoto) ...[
          const SizedBox(height: 16),
          SeedlyOptionCard(
            icon: 'assets/images/alert_cancel.svg',
            title: 'Quitar foto',
            description: 'Volver a mostrar tus iniciales',
            onTap: () => Navigator.of(context).pop(const SeedlyPhotoRemoved()),
          ),
        ],
      ],
    );
  }
}
