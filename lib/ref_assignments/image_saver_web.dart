import 'dart:typed_data';
import 'dart:html' as html;

class ImageSaveResult {
  const ImageSaveResult({required this.success, this.isSimulator = false});

  final bool success;
  final bool isSimulator;
}

Future<ImageSaveResult> savePngImage(Uint8List bytes, String name) async {
  try {
    final blob = html.Blob([bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = '$name.png'
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return const ImageSaveResult(success: true);
  } catch (_) {
    return const ImageSaveResult(success: false);
  }
}

bool isIosSimulator() => false;
