import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../services/image_encoder.dart';
import '../../shared/utils/avatar_crop.dart';

/// Pick the circle before it is written.
///
/// Silently centre-cropping someone's photograph takes the top of their head
/// off about a third of the time, and there is no way to tell from the
/// result that anything was decided on their behalf. So the crop is a step:
/// drag to position, pinch or use the slider to zoom, and what is inside the
/// circle is exactly what gets stored.
///
/// Pops the encoded JPEG bytes, or null if cancelled.
class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({super.key, required this.bytes});

  /// The picked photo, as it came from the camera or library.
  final Uint8List bytes;

  static const Key confirmKey = Key('avatar-crop-confirm');
  static const Key zoomKey = Key('avatar-crop-zoom');

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  Size? _imageSize;
  String? _problem;
  bool _working = false;

  double _scale = AvatarCrop.minScale;
  Offset _offset = Offset.zero;

  double _gestureStartScale = AvatarCrop.minScale;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  /// Side of the square crop viewport, measured at layout.
  double _viewport = 0;

  @override
  void initState() {
    super.initState();
    _imageSize = _probeSize(widget.bytes);
    if (_imageSize == null) _problem = 'That photo could not be opened.';
  }

  /// The intrinsic size, which the crop maths needs and a widget cannot ask
  /// an `Image` for before it has painted.
  ///
  /// Read from the file header rather than by decoding: it is synchronous,
  /// costs nothing, and does not go through the engine's image codec — which
  /// never completes inside a widget test's fake-async zone, so a crop
  /// screen that waited on one would sit disabled forever under test.
  static Size? _probeSize(Uint8List bytes) {
    try {
      final info = img.findDecoderForData(bytes)?.startDecode(bytes);
      if (info == null || info.width <= 0 || info.height <= 0) return null;
      return Size(info.width.toDouble(), info.height.toDouble());
    } catch (_) {
      return null;
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    _gestureStartScale = _scale;
    _gestureStartOffset = _offset;
    _gestureStartFocal = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final image = _imageSize;
    if (image == null) return;

    final scale = (_gestureStartScale * d.scale)
        .clamp(AvatarCrop.minScale, AvatarCrop.maxScale);
    // Carry the existing pan through the zoom in proportion, so whatever was
    // under the middle of the circle stays there instead of jumping.
    final ratio = scale / _gestureStartScale;
    final panned =
        _gestureStartOffset * ratio + (d.focalPoint - _gestureStartFocal);

    setState(() {
      _scale = scale;
      _offset = AvatarCrop.clampOffset(panned,
          image: image, viewport: _viewport, scale: scale);
    });
  }

  void _setZoom(double scale) {
    final image = _imageSize;
    if (image == null) return;
    setState(() {
      final ratio = scale / _scale;
      _scale = scale;
      _offset = AvatarCrop.clampOffset(_offset * ratio,
          image: image, viewport: _viewport, scale: scale);
    });
  }

  Future<void> _confirm() async {
    final image = _imageSize;
    if (image == null || _working) return;

    setState(() {
      _working = true;
      _problem = null;
    });

    try {
      final rect = AvatarCrop.sourceRect(
        image: image,
        viewport: _viewport,
        scale: _scale,
        offset: _offset,
      );
      final cropped = ImageEncoder.croppedAvatar(
        widget.bytes,
        x: rect.left.round(),
        y: rect.top.round(),
        width: rect.width.round(),
        height: rect.height.round(),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop<Uint8List>(cropped);
    } on ImageDecodeException catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _problem = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final image = _imageSize;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Position your photo'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.xl),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Square, and never wider than the shorter side of
                      // what we were given.
                      final side = constraints.biggest.shortestSide;
                      _viewport = side;

                      if (image == null) {
                        // A static placeholder, not a spinner. Reading the
                        // photo's dimensions takes a frame or two, so a
                        // spinner here would only ever flash — and an
                        // ambient repeating animation never finishes, which
                        // burns frames in the app and hangs pumpAndSettle in
                        // a test.
                        return SizedBox.square(
                          dimension: side,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.surfaceContainerHigh,
                            ),
                            child: Center(
                              child: Icon(
                                _problem != null
                                    ? Icons.broken_image_outlined
                                    : Icons.photo_outlined,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }

                      final drawn = AvatarCrop.coverScale(image, side) * _scale;

                      return GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        child: SizedBox.square(
                          dimension: side,
                          child: ClipOval(
                            child: ColoredBox(
                              color: scheme.surfaceContainerHigh,
                              child: ClipRect(
                                child: OverflowBox(
                                  maxWidth: double.infinity,
                                  maxHeight: double.infinity,
                                  child: Transform.translate(
                                    offset: _offset,
                                    child: SizedBox(
                                      width: image.width * drawn,
                                      height: image.height * drawn,
                                      child: Image.memory(
                                        widget.bytes,
                                        fit: BoxFit.fill,
                                        gaplessPlayback: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: Space.xl),
              // A slider as well as the pinch: pinching needs two fingers
              // and a free hand, and neither is a given.
              Row(
                children: [
                  Icon(Icons.zoom_out_rounded,
                      size: 18, color: scheme.onSurfaceVariant),
                  Expanded(
                    child: Slider(
                      key: AvatarCropScreen.zoomKey,
                      value: _scale,
                      min: AvatarCrop.minScale,
                      max: AvatarCrop.maxScale,
                      label: '${_scale.toStringAsFixed(1)}×',
                      semanticFormatterCallback: (v) =>
                          'Zoom ${v.toStringAsFixed(1)} times',
                      onChanged: image == null ? null : _setZoom,
                    ),
                  ),
                  Icon(Icons.zoom_in_rounded,
                      size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
              Text(
                'Drag to move, pinch or slide to zoom.',
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (_problem != null) ...[
                const SizedBox(height: Space.lg),
                Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 18, color: scheme.error),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(_problem!,
                          style: text.bodySmall?.copyWith(color: scheme.error)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Space.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: AvatarCropScreen.confirmKey,
                  onPressed: image == null || _working ? null : _confirm,
                  // AnimatedSize, not a cross-fade: the label changes width
                  // and a hard jump reads as the button being replaced.
                  child: AnimatedSize(
                    duration: context.motion(Motion.quick),
                    curve: Motion.standard,
                    child: Text(_working ? 'Saving…' : 'Use this photo'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
