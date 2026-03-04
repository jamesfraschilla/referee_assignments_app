import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import 'image_saver.dart';
import 'models.dart';
import 'photo_resolver.dart';

const Size portraitExportSize = Size(1536, 2592);
const Size landscapeExportSize = Size(3300, 2550);
const Size wasExportSize = Size(3840, 2160);
const Size wasContentSize = Size(802, 1300);

const Size portraitCanvasSize = Size(384, 648);
const Size landscapeCanvasSize = Size(660, 510);

enum AssignmentExportFormat { portrait, landscape, was }

Size assignmentCanvasSize(AssignmentExportFormat format) {
  switch (format) {
    case AssignmentExportFormat.portrait:
    case AssignmentExportFormat.was:
      return portraitCanvasSize;
    case AssignmentExportFormat.landscape:
      return landscapeCanvasSize;
  }
}

TextStyle _exportTextStyle({
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
  required String fontFamily,
  required double height,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    fontFamily: fontFamily,
    height: height,
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );
}

String assignmentExportButtonLabel(AssignmentExportFormat format) {
  final isWeb = kIsWeb;
  switch (format) {
    case AssignmentExportFormat.portrait:
      return isWeb ? 'Portrait PNG' : 'Portrait';
    case AssignmentExportFormat.landscape:
      return isWeb ? 'Landscape PNG' : 'Landscape';
    case AssignmentExportFormat.was:
      return isWeb ? 'WAS PNG' : 'WAS';
  }
}

Future<void> exportAssignmentImage(
  BuildContext context, {
  required RefereeGameAssignment assignment,
  required AssignmentExportFormat format,
  required Color backgroundColor,
}) async {
  final overlay = Overlay.maybeOf(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (overlay == null) {
    _showSnackBar(messenger, 'Export failed: overlay unavailable.');
    return;
  }

  final textColor = backgroundColor.computeLuminance() < 0.5
      ? Colors.white
      : Colors.black;
  final primaryOfficials =
      assignment.officials
          .where((official) => official.role != OfficialRole.alternate)
          .toList()
        ..sort(
          (a, b) => _rolePriority(a.role).compareTo(_rolePriority(b.role)),
        );
  final alternate = assignment.officials
      .where((official) => official.role == OfficialRole.alternate)
      .map((official) => official.name)
      .toList();

  final portraitKey = GlobalKey();
  final landscapeKey = GlobalKey();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      return Positioned(
        left: -10000,
        top: 0,
        child: IgnorePointer(
          child: _HiddenExportCanvases(
            portraitKey: portraitKey,
            landscapeKey: landscapeKey,
            primaryOfficials: primaryOfficials,
            alternate: alternate,
            backgroundColor: backgroundColor,
            textColor: textColor,
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
  try {
    for (final official in primaryOfficials) {
      await precacheImage(AssetImage(refereeAssetPath(official.name)), context);
    }
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    final captureFormat = format == AssignmentExportFormat.landscape
        ? AssignmentExportFormat.landscape
        : AssignmentExportFormat.portrait;
    final boundaryKey = captureFormat == AssignmentExportFormat.landscape
        ? landscapeKey
        : portraitKey;
    final logicalSize = assignmentCanvasSize(captureFormat);
    final targetSize = switch (format) {
      AssignmentExportFormat.portrait => portraitExportSize,
      AssignmentExportFormat.landscape => landscapeExportSize,
      AssignmentExportFormat.was => wasExportSize,
    };
    final captureTarget = format == AssignmentExportFormat.was
        ? wasContentSize
        : targetSize;

    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      _showSnackBar(messenger, 'Unable to locate layout for export.');
      return;
    }
    final size = boundary.size;
    if (size.width == 0 || size.height == 0) {
      _showSnackBar(messenger, 'Export failed: layout not ready.');
      return;
    }

    final widthRatio = captureTarget.width / logicalSize.width;
    final heightRatio = captureTarget.height / logicalSize.height;
    var pixelRatio = widthRatio > heightRatio ? widthRatio : heightRatio;
    if (pixelRatio < 1.0) {
      pixelRatio = 1.0;
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final pngBytes = await renderAssignmentPngBytes(
        image,
        targetSize: targetSize,
        backgroundColor: backgroundColor,
        contentSize: format == AssignmentExportFormat.was
            ? wasContentSize
            : null,
      );
      if (pngBytes == null) {
        _showSnackBar(messenger, 'Export failed: could not encode image.');
        return;
      }
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final result = await savePngImage(pngBytes, 'ref_assignment_$timestamp');
      if (result.isSimulator) {
        _showSnackBar(
          messenger,
          'Preview exported. Photos app unavailable on simulator.',
        );
        return;
      }
      final successMessage = kIsWeb
          ? 'Download started.'
          : 'Exported to Photos.';
      final failureMessage = kIsWeb
          ? 'Download failed.'
          : 'Export failed while saving.';
      _showSnackBar(
        messenger,
        result.success ? successMessage : failureMessage,
      );
    } finally {
      image.dispose();
    }
  } catch (e) {
    _showSnackBar(messenger, 'Export failed: $e');
  } finally {
    entry.remove();
  }
}

class AssignmentExportPreview extends StatelessWidget {
  const AssignmentExportPreview({
    super.key,
    required this.assignment,
    required this.format,
    required this.backgroundColor,
    required this.textColor,
  });

  final RefereeGameAssignment assignment;
  final AssignmentExportFormat format;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final primaryOfficials =
        assignment.officials
            .where((official) => official.role != OfficialRole.alternate)
            .toList()
          ..sort(
            (a, b) => _rolePriority(a.role).compareTo(_rolePriority(b.role)),
          );
    final alternate = assignment.officials
        .where((official) => official.role == OfficialRole.alternate)
        .map((official) => official.name)
        .toList();

    return AssignmentExportCanvas(
      format: format,
      primaryOfficials: primaryOfficials,
      alternate: alternate,
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
  }
}

class AssignmentExportCanvas extends StatelessWidget {
  const AssignmentExportCanvas({
    super.key,
    required this.format,
    required this.primaryOfficials,
    required this.alternate,
    required this.backgroundColor,
    required this.textColor,
  });

  final AssignmentExportFormat format;
  final List<RefereeOfficial> primaryOfficials;
  final List<String> alternate;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: format == AssignmentExportFormat.landscape
          ? _LandscapeExportLayout(
              primaryOfficials: primaryOfficials,
              alternate: alternate,
              textColor: textColor,
            )
          : _PortraitExportLayout(
              primaryOfficials: primaryOfficials,
              alternate: alternate,
              textColor: textColor,
            ),
    );
  }
}

class _HiddenExportCanvases extends StatelessWidget {
  const _HiddenExportCanvases({
    required this.portraitKey,
    required this.landscapeKey,
    required this.primaryOfficials,
    required this.alternate,
    required this.backgroundColor,
    required this.textColor,
  });

  final GlobalKey portraitKey;
  final GlobalKey landscapeKey;
  final List<RefereeOfficial> primaryOfficials;
  final List<String> alternate;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          key: portraitKey,
          child: SizedBox(
            width: portraitCanvasSize.width,
            height: portraitCanvasSize.height,
            child: AssignmentExportCanvas(
              format: AssignmentExportFormat.portrait,
              primaryOfficials: primaryOfficials,
              alternate: alternate,
              backgroundColor: backgroundColor,
              textColor: textColor,
            ),
          ),
        ),
        RepaintBoundary(
          key: landscapeKey,
          child: SizedBox(
            width: landscapeCanvasSize.width,
            height: landscapeCanvasSize.height,
            child: AssignmentExportCanvas(
              format: AssignmentExportFormat.landscape,
              primaryOfficials: primaryOfficials,
              alternate: alternate,
              backgroundColor: backgroundColor,
              textColor: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _PortraitExportLayout extends StatelessWidget {
  const _PortraitExportLayout({
    required this.primaryOfficials,
    required this.alternate,
    required this.textColor,
  });

  final List<RefereeOfficial> primaryOfficials;
  final List<String> alternate;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final headerStyle = _exportTextStyle(
      fontSize: portraitCanvasSize.width * 0.075,
      fontWeight: FontWeight.w700,
      color: textColor,
      fontFamily: 'DIN',
      height: 1.0,
    );
    final footerStyle = _exportTextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: textColor,
      fontFamily: 'DINalt',
      height: 1.0,
    );

    if (primaryOfficials.isEmpty) {
      return Center(
        child: Text(
          'Officials not posted.',
          style: headerStyle.copyWith(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
      child: Column(
        children: [
          Text(
            "TONIGHT'S OFFICIALS",
            style: headerStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final official in primaryOfficials)
                  _ExportOfficialTile.portrait(
                    official: official,
                    textColor: textColor,
                  ),
              ],
            ),
          ),
          if (alternate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Alternate: ${alternate.join(', ')}',
                style: footerStyle,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _LandscapeExportLayout extends StatelessWidget {
  const _LandscapeExportLayout({
    required this.primaryOfficials,
    required this.alternate,
    required this.textColor,
  });

  final List<RefereeOfficial> primaryOfficials;
  final List<String> alternate;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final headerStyle = _exportTextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w700,
      color: textColor,
      fontFamily: 'DIN',
      height: 1.0,
    );
    final footerStyle = _exportTextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: textColor,
      fontFamily: 'DINalt',
      height: 1.0,
    );

    if (primaryOfficials.isEmpty) {
      return Center(
        child: Text(
          'Officials not posted.',
          style: headerStyle.copyWith(fontSize: 20),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Text(
            "TONIGHT'S OFFICIALS",
            style: headerStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 360,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (
                  var index = 0;
                  index < primaryOfficials.length;
                  index++
                ) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _ExportOfficialTile.landscape(
                      official: primaryOfficials[index],
                      textColor: textColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(flex: 1),
          if (alternate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Alternate: ${alternate.join(', ')}',
                style: footerStyle,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExportOfficialTile extends StatelessWidget {
  const _ExportOfficialTile.portrait({
    required this.official,
    required this.textColor,
  }) : isPortrait = true;

  const _ExportOfficialTile.landscape({
    required this.official,
    required this.textColor,
  }) : isPortrait = false;

  final RefereeOfficial official;
  final Color textColor;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    final nameParts = _DisplayNameParts.from(official.name);
    final primaryFontSize = isPortrait ? 23.0 : 20.0;
    final secondaryFontSize = isPortrait ? 15.0 : 13.0;
    final roleFontSize = isPortrait ? 11.0 : 10.0;
    final avatarSize = isPortrait ? 120.0 : 170.0;
    final imageRadius = BorderRadius.circular(isPortrait ? 18 : 20);
    final lineOne = [
      if (official.number != null) '#${official.number}',
      if (nameParts.first.isNotEmpty) nameParts.first,
      if (isPortrait && nameParts.last.isNotEmpty) nameParts.last,
    ].join(' ');
    final secondLine = isPortrait ? '' : nameParts.last;

    final lineOneStyle = _exportTextStyle(
      fontSize: primaryFontSize,
      fontWeight: FontWeight.w700,
      color: textColor,
      fontFamily: 'DINalt',
      height: 0.95,
    );
    final lineTwoStyle = _exportTextStyle(
      fontSize: secondaryFontSize,
      fontWeight: FontWeight.w600,
      color: textColor,
      fontFamily: 'DINalt',
      height: 0.95,
    );
    final roleStyle = _exportTextStyle(
      fontSize: roleFontSize,
      fontWeight: FontWeight.w600,
      color: textColor,
      fontFamily: 'DINalt',
      height: 1.0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (isPortrait ? portraitCanvasSize.width - 48 : 170.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: imageRadius,
              child: SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: Image.asset(
                  refereeAssetPath(official.name),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) {
                    return ColoredBox(
                      color: const Color(0xFFE8E8E8),
                      child: Center(
                        child: Text(
                          _initials(official.name),
                          style: lineOneStyle.copyWith(
                            color: Colors.black,
                            fontSize: primaryFontSize * 0.9,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: isPortrait ? 8 : 10),
            _ScaledLine(text: lineOne, style: lineOneStyle, width: textWidth),
            if (secondLine.isNotEmpty) ...[
              const SizedBox(height: 2),
              _ScaledLine(
                text: secondLine,
                style: lineTwoStyle,
                width: textWidth,
              ),
            ],
            SizedBox(height: isPortrait ? 2 : 4),
            Text(
              officialRoleLabel(official.role),
              style: roleStyle,
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

class _ScaledLine extends StatelessWidget {
  const _ScaledLine({
    required this.text,
    required this.style,
    required this.width,
  });

  final String text;
  final TextStyle style;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: style,
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _DisplayNameParts {
  const _DisplayNameParts({required this.first, required this.last});

  final String first;
  final String last;

  factory _DisplayNameParts.from(String rawName) {
    final parts = rawName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return const _DisplayNameParts(first: '', last: '');
    }
    if (parts.length == 1) {
      return _DisplayNameParts(first: parts.first.toUpperCase(), last: '');
    }
    return _DisplayNameParts(
      first: parts.first.toUpperCase(),
      last: parts.sublist(1).join(' ').toUpperCase(),
    );
  }
}

String _initials(String raw) {
  final parts = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return '';
  }
  final first = parts.first;
  final last = parts.length > 1 ? parts.last : '';
  final buffer = StringBuffer();
  if (first.isNotEmpty) {
    buffer.write(first[0]);
  }
  if (last.isNotEmpty) {
    buffer.write(last[0]);
  }
  final value = buffer.toString();
  return value.isEmpty ? raw[0].toUpperCase() : value.toUpperCase();
}

Future<Uint8List?> renderAssignmentPngBytes(
  ui.Image image, {
  required Size targetSize,
  required Color backgroundColor,
  Size? contentSize,
}) async {
  final int targetWidth = targetSize.width.toInt();
  final int targetHeight = targetSize.height.toInt();
  ui.Picture? picture;
  ui.Image? processed;
  try {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint();
    if (contentSize == null) {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, targetSize.width, targetSize.height),
        paint..color = backgroundColor,
      );
      _drawFittedImage(
        canvas,
        image: image,
        target: ui.Rect.fromLTWH(0, 0, targetSize.width, targetSize.height),
      );
    } else {
      final isDark = backgroundColor.computeLuminance() < 0.5;
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, targetSize.width, targetSize.height),
        paint..color = Colors.white,
      );
      final contentRect = ui.Rect.fromLTWH(
        0,
        0,
        contentSize.width,
        contentSize.height,
      );
      canvas.drawRect(
        contentRect,
        paint..color = isDark ? Colors.black : Colors.white,
      );
      _drawFittedImage(canvas, image: image, target: contentRect);
    }
    picture = recorder.endRecording();
    processed = await picture.toImage(targetWidth, targetHeight);
    final byteData = await processed.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return null;
    }
    return byteData.buffer.asUint8List();
  } finally {
    processed?.dispose();
    picture?.dispose();
  }
}

void _drawFittedImage(
  ui.Canvas canvas, {
  required ui.Image image,
  required ui.Rect target,
}) {
  final widthScale = target.width / image.width;
  double scaledWidth = target.width;
  double scaledHeight = image.height * widthScale;
  double offsetX = target.left;
  double offsetY = target.top + (target.height - scaledHeight) / 2;
  if (scaledHeight > target.height) {
    final heightScale = target.height / image.height;
    scaledHeight = target.height;
    scaledWidth = image.width * heightScale;
    offsetY = target.top;
    offsetX = target.left + (target.width - scaledWidth) / 2;
  }
  final src = ui.Rect.fromLTWH(
    0,
    0,
    image.width.toDouble(),
    image.height.toDouble(),
  );
  final dst = ui.Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight);
  canvas.drawImageRect(image, src, dst, Paint());
}

void _showSnackBar(ScaffoldMessengerState? messenger, String message) {
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

int _rolePriority(OfficialRole role) {
  switch (role) {
    case OfficialRole.crewChief:
      return 0;
    case OfficialRole.referee:
      return 1;
    case OfficialRole.umpire:
      return 2;
    case OfficialRole.alternate:
      return 3;
  }
}
