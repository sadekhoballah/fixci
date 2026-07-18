import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:permission_handler/permission_handler.dart';

class PickedImage {
  PickedImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final List<int> bytes;
  final String filename;
  final String mimeType;
}

class IdCardPickerException implements Exception {
  IdCardPickerException(this.message);

  final String message;

  @override
  String toString() => message;
}

// image_picker has no official Linux (or Windows) desktop implementation, so
// those platforms fall back to a plain file dialog via file_selector, and
// there's no camera capture path there either.
bool get idCardCameraSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

bool get _imagePickerSupported =>
    kIsWeb || !(Platform.isLinux || Platform.isWindows);

String _mimeTypeFor(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  return 'image/jpeg';
}

class IdCardPicker {
  const IdCardPicker();

  Future<PickedImage?> pickFromGallery() async {
    if (_imagePickerSupported) {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return null;
      return PickedImage(
        bytes: await file.readAsBytes(),
        filename: file.name,
        mimeType: file.mimeType ?? _mimeTypeFor(file.name),
      );
    }

    final file = await file_selector.openFile(
      acceptedTypeGroups: const [
        file_selector.XTypeGroup(
          label: 'images',
          extensions: ['jpg', 'jpeg', 'png'],
        ),
      ],
    );
    if (file == null) return null;
    return PickedImage(
      bytes: await file.readAsBytes(),
      filename: file.name,
      mimeType: file.mimeType ?? _mimeTypeFor(file.name),
    );
  }

  Future<PickedImage?> pickFromCamera() async {
    if (!idCardCameraSupported) {
      throw IdCardPickerException(
        "La caméra n'est pas disponible sur cet appareil.",
      );
    }

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      throw IdCardPickerException(
        "Autorisation caméra refusée. Activez-la dans les paramètres de l'appareil.",
      );
    }

    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    if (file == null) return null;
    return PickedImage(
      bytes: await file.readAsBytes(),
      filename: file.name,
      mimeType: file.mimeType ?? _mimeTypeFor(file.name),
    );
  }
}

final idCardPickerProvider = Provider<IdCardPicker>(
  (ref) => const IdCardPicker(),
);
