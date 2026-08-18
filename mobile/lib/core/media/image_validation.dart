import 'dart:typed_data';
import 'dart:ui' as ui;
import '../../l10n/app_localizations.dart';

enum ImageValidationError {
  emptyFile,
  fileTooLarge,
  unsupportedFormat,
  corruptedFile,
  lowResolution,
  wrongAspectRatio,
}

extension ImageValidationErrorLocalization on ImageValidationError {
  String localizedMessage(AppLocalizations l10n) => switch (this) {
    ImageValidationError.emptyFile => l10n.imageEmptyFileMessage,
    ImageValidationError.fileTooLarge => l10n.imageTooLargeMessage,
    ImageValidationError.unsupportedFormat =>
      l10n.imageUnsupportedFormatMessage,
    ImageValidationError.corruptedFile => l10n.imageCorruptedMessage,
    ImageValidationError.lowResolution => l10n.imageLowResolutionMessage,
    ImageValidationError.wrongAspectRatio =>
      l10n.imageWrongAspectRatioMessage,
  };
}

class ImageValidationException implements Exception {
  ImageValidationException(this.error);

  final ImageValidationError error;

  @override
  String toString() => error.name;
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
    throw ImageValidationException(ImageValidationError.emptyFile);
  }
  if (bytes.length > maxIdCardSizeBytes) {
    throw ImageValidationException(ImageValidationError.fileTooLarge);
  }
  if (!_looksLikeJpegOrPng(bytes)) {
    throw ImageValidationException(ImageValidationError.unsupportedFormat);
  }

  final ui.Codec codec;
  try {
    codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  } catch (_) {
    throw ImageValidationException(ImageValidationError.corruptedFile);
  }
  final frame = await codec.getNextFrame();
  final width = frame.image.width;
  final height = frame.image.height;
  frame.image.dispose();

  final shorter = width < height ? width : height;
  final longer = width < height ? height : width;

  if (shorter < minIdCardDimension) {
    throw ImageValidationException(ImageValidationError.lowResolution);
  }
  if (longer / shorter > maxIdCardAspectRatio) {
    throw ImageValidationException(ImageValidationError.wrongAspectRatio);
  }
}

// Mission/Freelance photo counterpart — same size/format/dimension floor as
// validateIdCardImage, but deliberately no aspect-ratio cap: a repair/job
// photo can be any shape, unlike an ID document. Kept in sync with
// backend/src/uploads/uploads.controller.ts's assertLooksLikeGenericPhoto.
Future<void> validateGenericPhotoImage(List<int> bytes) async {
  if (bytes.isEmpty) {
    throw ImageValidationException(ImageValidationError.emptyFile);
  }
  if (bytes.length > maxIdCardSizeBytes) {
    throw ImageValidationException(ImageValidationError.fileTooLarge);
  }
  if (!_looksLikeJpegOrPng(bytes)) {
    throw ImageValidationException(ImageValidationError.unsupportedFormat);
  }

  final ui.Codec codec;
  try {
    codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  } catch (_) {
    throw ImageValidationException(ImageValidationError.corruptedFile);
  }
  final frame = await codec.getNextFrame();
  final width = frame.image.width;
  final height = frame.image.height;
  frame.image.dispose();

  final shorter = width < height ? width : height;
  if (shorter < minIdCardDimension) {
    throw ImageValidationException(ImageValidationError.lowResolution);
  }
}
