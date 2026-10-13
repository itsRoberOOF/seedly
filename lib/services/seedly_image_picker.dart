import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class SeedlyImagePickerException implements Exception {
  const SeedlyImagePickerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Picks project photos, so tests can skip the system picker.
abstract interface class SeedlyImagePicker {
  /// The photo as a small JPEG, or null if the person closed the picker.
  /// Throws [SeedlyImagePickerException] with a message ready to show.
  Future<Uint8List?> pickFromGallery();
}

/// Opens the system photo picker (no permission needed on Android 13+) and
/// shrinks the photo to an avatar-sized JPEG that fits in a Firestore
/// document.
class GallerySeedlyImagePicker implements SeedlyImagePicker {
  GallerySeedlyImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Twice the 108px avatar circle, for sharp screens.
  static const size = 256.0;

  /// Firestore documents cap at 1 MiB; this leaves room for the rest.
  static const maxBytes = 256 * 1024;

  @override
  Future<Uint8List?> pickFromGallery() async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: size,
        maxHeight: size,
        imageQuality: 75,
        requestFullMetadata: false,
      );
    } on PlatformException {
      throw const SeedlyImagePickerException(
        'No se pudo abrir tu galería. Revisa los permisos de fotos.',
      );
    }
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const SeedlyImagePickerException(
        'La imagen es demasiado grande. Prueba con otra.',
      );
    }
    return bytes;
  }
}
