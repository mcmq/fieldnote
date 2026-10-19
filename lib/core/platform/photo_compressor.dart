import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Re-encodes a picked image as a small JPEG (max 1024px, quality 60) so it
/// fits in a Firestore document. `image_picker` can't guarantee this because
/// PNG/HEIC sources may ignore its quality setting.
Future<File> compressPhoto(File source, String destPath) async {
  final bytes = await source.readAsBytes();
  final out = await compute(_encode, bytes);
  return File(destPath).writeAsBytes(out);
}

Uint8List _encode(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw StateError('Unsupported image format');
  final oriented = img.bakeOrientation(decoded);
  final longest = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final resized = longest > 1024
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? 1024 : null,
          height: oriented.height > oriented.width ? 1024 : null,
        )
      : oriented;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 60));
}
