import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Where a photo is coming from.
enum PhotoOrigin {
  camera,
  gallery;

  String get label =>
      this == PhotoOrigin.camera ? 'Take a photo' : 'Choose a photo';
}

/// The person declined the permission the picker needs.
///
/// A normal path, not an error state: plenty of people say no to the camera
/// and still want to pick from their library. Typed so the UI can offer the
/// other route instead of showing a failure.
class PhotoAccessDenied implements Exception {
  const PhotoAccessDenied(this.origin);

  final PhotoOrigin origin;

  String get message => origin == PhotoOrigin.camera
      ? 'Strata does not have permission to use the camera.'
      : 'Strata does not have permission to open your photos.';
}

/// Something went wrong reaching the picker itself.
class PhotoPickFailed implements Exception {
  const PhotoPickFailed([this.message = 'Could not open the picker.']);

  final String message;
}

/// Getting bytes from the person's camera or library.
///
/// An interface so the screens never import `image_picker` — a test can
/// supply bytes directly, and a buyer swapping the plugin changes one class.
abstract interface class PhotoPicker {
  /// Bytes of the chosen photo, or null when the person backed out.
  ///
  /// Throws [PhotoAccessDenied] on a refused permission and
  /// [PhotoPickFailed] on anything else.
  Future<Uint8List?> pick(PhotoOrigin origin);
}

/// The real picker, over `image_picker`.
class PlatformPhotoPicker implements PhotoPicker {
  PlatformPhotoPicker({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Asked for at a sane size rather than full resolution: a 12MP frame
  /// costs ~48MB decoded, and the crop step only needs enough pixels to
  /// stay sharp at 512.
  static const double _maxEdge = 2048;

  @override
  Future<Uint8List?> pick(PhotoOrigin origin) async {
    try {
      final file = await _picker.pickImage(
        source: origin == PhotoOrigin.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: _maxEdge,
        maxHeight: _maxEdge,
        requestFullMetadata: false,
      );
      // Null means dismissed, which is not a failure.
      if (file == null) return null;
      return await file.readAsBytes();
    } on Exception catch (e) {
      final text = e.toString();
      // The plugin reports a refusal as a PlatformException with one of
      // these codes. Matching on the text keeps this class free of a
      // platform-channel import for the sake of one `is` check.
      if (text.contains('camera_access_denied')) {
        throw const PhotoAccessDenied(PhotoOrigin.camera);
      }
      if (text.contains('photo_access_denied')) {
        throw const PhotoAccessDenied(PhotoOrigin.gallery);
      }
      throw PhotoPickFailed('Could not open ${origin.label.toLowerCase()}.');
    }
  }
}
