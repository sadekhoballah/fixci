import 'dart:typed_data';
import 'dart:ui' as ui;

class ImageValidationException implements Exception {
  ImageValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

// Kept in sync with backend/src/uploads/uploads.constants.ts — the server
// re-checks all of this independently, this is just a fast client-side
// rejection so the user isn't waiting on an upload to find out.
const maxIdCardSizeBytes = 5 * 1024 * 1024;
const minIdCardDimension = 300;
const maxIdCardAspectRatio = 3.0;

bool _looksLikeJpegOrPng(List<int> bytes) {
  if (bytes.length < 8) return false;
  final isPng =
      bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
  final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
  return isPng || isJpeg;
}

Future<void> validateIdCardImage(List<int> bytes) async {
  if (bytes.isEmpty) {
    throw ImageValidationException('Le fichier est vide.');
  }
  if (bytes.length > maxIdCardSizeBytes) {
    throw ImageValidationException(
      "L'image dépasse la taille maximale de 5 Mo.",
    );
  }
  if (!_looksLikeJpegOrPng(bytes)) {
    throw ImageValidationException(
      'Seules les images JPEG ou PNG sont acceptées.',
    );
  }

  final ui.Codec codec;
  try {
    codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  } catch (_) {
    throw ImageValidationException(
      'Le fichier image est corrompu ou illisible.',
    );
  }
  final frame = await codec.getNextFrame();
  final width = frame.image.width;
  final height = frame.image.height;
  frame.image.dispose();

  final shorter = width < height ? width : height;
  final longer = width < height ? height : width;

  if (shorter < minIdCardDimension) {
    throw ImageValidationException(
      'La résolution de l\'image est trop faible pour être lisible.',
    );
  }
  if (longer / shorter > maxIdCardAspectRatio) {
    throw ImageValidationException(
      "Les proportions de l'image ne ressemblent pas à une pièce d'identité.",
    );
  }
}
