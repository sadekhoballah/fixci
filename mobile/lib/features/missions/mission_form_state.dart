import 'dart:typed_data';

enum MissionFormStatus { idle, locating, submitting, success, error }

// One picked-and-uploaded photo. Uploaded immediately on pick (mirrors
// CraftsmanHomeController._resubmitIdCard's pick-then-upload sequence)
// rather than deferred to submit time, so the form only ever holds
// already-valid storage keys — bytes are kept alongside purely for the
// local thumbnail preview.
class MissionPhotoDraft {
  const MissionPhotoDraft({required this.bytes, required this.storageKey});

  final Uint8List bytes;
  final String storageKey;
}

const maxMissionPhotos = 3;

class MissionFormState {
  const MissionFormState({
    this.status = MissionFormStatus.idle,
    this.errorMessage,
    this.createdMissionId,
    this.photos = const [],
    this.isUploadingPhoto = false,
  });

  final MissionFormStatus status;
  final String? errorMessage;
  final String? createdMissionId;
  final List<MissionPhotoDraft> photos;
  final bool isUploadingPhoto;

  MissionFormState copyWith({
    MissionFormStatus? status,
    String? errorMessage,
    bool clearError = false,
    String? createdMissionId,
    List<MissionPhotoDraft>? photos,
    bool? isUploadingPhoto,
  }) {
    return MissionFormState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdMissionId: createdMissionId ?? this.createdMissionId,
      photos: photos ?? this.photos,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
    );
  }
}
