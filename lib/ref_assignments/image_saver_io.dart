import 'dart:io';
import 'dart:typed_data';

import 'package:image_gallery_saver/image_gallery_saver.dart';

class ImageSaveResult {
  const ImageSaveResult({required this.success, this.isSimulator = false});

  final bool success;
  final bool isSimulator;
}

Future<ImageSaveResult> savePngImage(Uint8List bytes, String name) async {
  if (isIosSimulator()) {
    return const ImageSaveResult(success: false, isSimulator: true);
  }
  final result = await ImageGallerySaver.saveImage(
    bytes,
    name: name,
    isReturnImagePathOfIOS: true,
  );
  return ImageSaveResult(success: _isSaveSuccessful(result));
}

bool isIosSimulator() {
  try {
    return Platform.isIOS &&
        Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');
  } catch (_) {
    return false;
  }
}

bool _isSaveSuccessful(dynamic result) {
  if (result is Map) {
    final keys = ['isSuccess', 'success', 'status'];
    for (final key in keys) {
      final value = result[key];
      if (value is bool) {
        return value;
      }
      if (value is String) {
        return value.toLowerCase() == 'success';
      }
    }
  }
  return false;
}
