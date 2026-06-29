/// Matches the backend's assessment_photos.type enum exactly.
enum PhotoType { angleFront, angleRear, angleLeft, angleRight, closeup }

extension PhotoTypeX on PhotoType {
  String get apiValue {
    switch (this) {
      case PhotoType.angleFront:
        return 'angle_front';
      case PhotoType.angleRear:
        return 'angle_rear';
      case PhotoType.angleLeft:
        return 'angle_left';
      case PhotoType.angleRight:
        return 'angle_right';
      case PhotoType.closeup:
        return 'closeup';
    }
  }

  String get label {
    switch (this) {
      case PhotoType.angleFront:
        return 'Front';
      case PhotoType.angleRear:
        return 'Rear';
      case PhotoType.angleLeft:
        return 'Left side';
      case PhotoType.angleRight:
        return 'Right side';
      case PhotoType.closeup:
        return 'Damage close-up';
    }
  }
}

/// The 4 required angle shots, in capture order.
/// Close-ups are added separately afterwards, not part of this fixed list,
/// since there can be zero or many of them (see spec edge case: a clean
/// car may have zero close-ups and that's still a valid assessment).
const requiredAngleSteps = [
  PhotoType.angleFront,
  PhotoType.angleRear,
  PhotoType.angleLeft,
  PhotoType.angleRight,
];

class CapturedPhoto {
  final PhotoType type;
  final String localPath;
  bool uploaded;
  int? photoId;

  CapturedPhoto({
    required this.type,
    required this.localPath,
    this.uploaded = false,
    this.photoId,
  });
}
