import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../image_saver.dart';
import '../models.dart';
import '../photo_resolver.dart';
import '../responsive.dart';

const Size _portraitExportSize = Size(1536, 2592);
const Size _landscapeExportSize = Size(3300, 2550);
const Size _wasExportSize = Size(3840, 2160);
const Size _wasContentSize = Size(802, 1300);

const Size _portraitCanvasSize = Size(384, 648);
const Size _landscapeCanvasSize = Size(660, 510);

enum _ExportFormat { portrait, landscape, was }

class AssignmentDetailScreen extends StatefulWidget {
  const AssignmentDetailScreen({
    super.key,
    required this.assignment,
    required this.assignmentDate,
    this.exportKey,
  });

  final RefereeGameAssignment assignment;
  final DateTime assignmentDate;
  final GlobalKey? exportKey;

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  static const List<DeviceOrientation> _allOrientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  late final GlobalKey _portraitExportKey = widget.exportKey ?? GlobalKey();
  final GlobalKey _landscapeExportKey = GlobalKey();
  bool _isExporting = false;
  bool _isPortraitLayout = true;
  Color _latestBackgroundColor = Colors.black;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(_allOrientations);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(_allOrientations);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    _latestBackgroundColor = backgroundColor;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final assignment = widget.assignment;
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
    final previewFormat = _isPortraitLayout
        ? _ExportFormat.portrait
        : _ExportFormat.landscape;
    final previewSize = _canvasSize(previewFormat);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = screenSizeForWidth(constraints.maxWidth);
            final outerPadding = switch (screenSize) {
              ScreenSize.compact => 12.0,
              ScreenSize.medium => 20.0,
              ScreenSize.expanded => 28.0,
            };

            final preview = Padding(
              padding: EdgeInsets.all(outerPadding),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: previewSize.width,
                    height: previewSize.height,
                    child: _AssignmentExportCanvas(
                      format: previewFormat,
                      primaryOfficials: primaryOfficials,
                      alternate: alternate,
                      backgroundColor: backgroundColor,
                      textColor: textColor,
                    ),
                  ),
                ),
              ),
            );

            final rotateButton = _ExportButton(
              isBusy: false,
              label: _isPortraitLayout ? 'Rotate Landscape' : 'Rotate Portrait',
              onPressed: _isExporting
                  ? null
                  : () {
                      setState(() {
                        _isPortraitLayout = !_isPortraitLayout;
                      });
                    },
            );
            final exportButton = _ExportButton(
              isBusy: _isExporting,
              label: kIsWeb ? 'Download PNG' : 'Export',
              onPressed: _isExporting
                  ? null
                  : () => _exportImage(
                      previewFormat == _ExportFormat.portrait
                          ? _ExportFormat.portrait
                          : _ExportFormat.landscape,
                    ),
            );
            final wasExportButton = _ExportButton(
              isBusy: _isExporting,
              label: kIsWeb ? 'Download WAS PNG' : 'Export WAS',
              onPressed: _isExporting
                  ? null
                  : () => _exportImage(_ExportFormat.was),
            );

            final actionButtons = <Widget>[
              rotateButton,
              const SizedBox(height: 12),
              exportButton,
              const SizedBox(height: 12),
              wasExportButton,
            ];

            final bodyContent = screenSize == ScreenSize.expanded
                ? Row(
                    children: [
                      Expanded(child: preview),
                      SafeArea(
                        top: false,
                        bottom: false,
                        left: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            0,
                            outerPadding,
                            outerPadding,
                            outerPadding,
                          ),
                          child: SizedBox(
                            width: 160,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: actionButtons,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: preview),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: actionButtons,
                        ),
                      ),
                    ],
                  );

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                bodyContent,
                Positioned(
                  top: 8,
                  left: 8,
                  child: _BackButton(backgroundColor: backgroundColor),
                ),
                Positioned(
                  left: -10000,
                  top: 0,
                  child: IgnorePointer(
                    child: _HiddenExportCanvases(
                      portraitKey: _portraitExportKey,
                      landscapeKey: _landscapeExportKey,
                      primaryOfficials: primaryOfficials,
                      alternate: alternate,
                      backgroundColor: backgroundColor,
                      textColor: textColor,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _exportImage(_ExportFormat format) async {
    setState(() => _isExporting = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      final captureFormat = format == _ExportFormat.landscape
          ? _ExportFormat.landscape
          : _ExportFormat.portrait;
      final boundaryKey = captureFormat == _ExportFormat.landscape
          ? _landscapeExportKey
          : _portraitExportKey;
      final logicalSize = _canvasSize(captureFormat);
      final targetSize = switch (format) {
        _ExportFormat.portrait => _portraitExportSize,
        _ExportFormat.landscape => _landscapeExportSize,
        _ExportFormat.was => _wasExportSize,
      };
      final captureTarget = format == _ExportFormat.was
          ? _wasContentSize
          : targetSize;
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        _showSnackBar('Unable to locate layout for export.');
        return;
      }
      final size = boundary.size;
      if (size.width == 0 || size.height == 0) {
        _showSnackBar('Export failed: layout not ready.');
        return;
      }

      final widthRatio = captureTarget.width / logicalSize.width;
      final heightRatio = captureTarget.height / logicalSize.height;
      var pixelRatio = widthRatio > heightRatio ? widthRatio : heightRatio;
      if (pixelRatio < 1.0) {
        pixelRatio = 1.0;
      }

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      await _saveImage(
        image,
        targetSize: targetSize,
        contentSize: format == _ExportFormat.was ? _wasContentSize : null,
      );
      image.dispose();
    } catch (e) {
      _showSnackBar('Export failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _saveImage(
    ui.Image image, {
    required Size targetSize,
    Size? contentSize,
  }) async {
    try {
      final pngBytes = await renderAssignmentPngBytes(
        image,
        targetSize: targetSize,
        backgroundColor: _latestBackgroundColor,
        contentSize: contentSize,
      );
      if (pngBytes == null) {
        _showSnackBar('Export failed: could not encode image.');
        return;
      }
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final result = await savePngImage(pngBytes, 'ref_assignment_$timestamp');
      if (result.isSimulator) {
        _showSnackBar('Preview exported. Photos app unavailable on simulator.');
        return;
      }
      final successMessage = kIsWeb
          ? 'Download started.'
          : 'Exported to Photos.';
      final failureMessage = kIsWeb
          ? 'Download failed.'
          : 'Export failed while saving.';
      _showSnackBar(result.success ? successMessage : failureMessage);
    } catch (e) {
      _showSnackBar('Export failed: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

Size _canvasSize(_ExportFormat format) {
  switch (format) {
    case _ExportFormat.portrait:
    case _ExportFormat.was:
      return _portraitCanvasSize;
    case _ExportFormat.landscape:
      return _landscapeCanvasSize;
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
            width: _portraitCanvasSize.width,
            height: _portraitCanvasSize.height,
            child: _AssignmentExportCanvas(
              format: _ExportFormat.portrait,
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
            width: _landscapeCanvasSize.width,
            height: _landscapeCanvasSize.height,
            child: _AssignmentExportCanvas(
              format: _ExportFormat.landscape,
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

class _AssignmentExportCanvas extends StatelessWidget {
  const _AssignmentExportCanvas({
    required this.format,
    required this.primaryOfficials,
    required this.alternate,
    required this.backgroundColor,
    required this.textColor,
  });

  final _ExportFormat format;
  final List<RefereeOfficial> primaryOfficials;
  final List<String> alternate;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: format == _ExportFormat.landscape
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
    final headerStyle = TextStyle(
      fontSize: _portraitCanvasSize.width * 0.075,
      fontWeight: FontWeight.w700,
      color: textColor,
      fontFamily: 'DINalt',
      height: 1.0,
    );
    final footerStyle = TextStyle(
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
    final headerStyle = TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w700,
      color: textColor,
      fontFamily: 'DINalt',
      height: 1.0,
    );
    final footerStyle = TextStyle(
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
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
      child: Column(
        children: [
          Text(
            "TONIGHT'S OFFICIALS",
            style: headerStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (
                  var index = 0;
                  index < primaryOfficials.length;
                  index++
                ) ...[
                  if (index > 0) const SizedBox(width: 18),
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
    final primaryFontSize = isPortrait ? 23.0 : 17.0;
    final secondaryFontSize = isPortrait ? 15.0 : 11.0;
    final roleFontSize = isPortrait ? 11.0 : 8.5;
    final avatarSize = isPortrait ? 120.0 : 138.0;
    final imageRadius = BorderRadius.circular(isPortrait ? 18 : 20);
    final lineOne = [
      if (official.number != null) '#${official.number}',
      if (nameParts.first.isNotEmpty) nameParts.first,
    ].join(' ');

    final lineOneStyle = TextStyle(
      fontSize: primaryFontSize,
      fontWeight: FontWeight.w700,
      color: textColor,
      fontFamily: 'DINalt',
      height: 0.95,
    );
    final lineTwoStyle = TextStyle(
      fontSize: secondaryFontSize,
      fontWeight: FontWeight.w600,
      color: textColor,
      fontFamily: 'DINalt',
      height: 0.95,
    );
    final roleStyle = TextStyle(
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
            : (isPortrait ? _portraitCanvasSize.width - 48 : 170.0);
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
            if (nameParts.last.isNotEmpty) ...[
              const SizedBox(height: 2),
              _ScaledLine(
                text: nameParts.last,
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

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.isBusy,
    required this.onPressed,
    required this.label,
  });

  final bool isBusy;
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final child = isBusy
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Exporting...'),
            ],
          )
        : Text(label);

    return SizedBox(
      width: 160,
      child: ElevatedButton(onPressed: onPressed, child: child),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.backgroundColor});

  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    if (!canPop) {
      return const SizedBox.shrink();
    }
    final isDark = backgroundColor.computeLuminance() < 0.5;
    final foreground = isDark ? Colors.white : Colors.black;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: foreground.withValues(alpha: 0.3)),
      ),
      child: IconButton(
        tooltip: 'Back',
        icon: Icon(Icons.arrow_back, color: foreground),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
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
