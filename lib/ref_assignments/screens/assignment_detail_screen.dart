import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../image_saver.dart';
import '../models.dart';
import '../responsive.dart';
import '../widgets/official_avatar.dart';

const Size _portraitExportSize = Size(1536, 2592);
const Size _landscapeExportSize = Size(3300, 2550);
const Size _wasExportSize = Size(3840, 2160);
const Size _wasContentSize = Size(802, 1300);
const double _portraitAspectRatio = 1536 / 2592;
const double _landscapeAspectRatio = 3300 / 2550;

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

  late final GlobalKey _exportKey = widget.exportKey ?? GlobalKey();
  bool _isExporting = false;
  Color _latestBackgroundColor = Colors.black;
  bool _forceCenteredLayout = false;
  bool _isPortraitLayout = true;

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
    final primaryOfficials = assignment.officials
        .where((official) => official.role != OfficialRole.alternate)
        .toList();
    primaryOfficials.sort(
      (a, b) => _rolePriority(a.role).compareTo(_rolePriority(b.role)),
    );
    final alternate = assignment.officials
        .where((official) => official.role == OfficialRole.alternate)
        .map((official) => official.name)
        .toList();
    const headerLabel = "TONIGHT'S OFFICIALS";
    final baseHeaderStyle =
        theme.textTheme.headlineMedium ??
        theme.textTheme.displaySmall ??
        theme.textTheme.titleLarge ??
        theme.textTheme.titleMedium;
    final headerBaseSize = baseHeaderStyle?.fontSize ?? 32;
    final headerStyle =
        (baseHeaderStyle ??
                const TextStyle(fontSize: 32, fontWeight: FontWeight.w700))
            .copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: headerBaseSize * 1.3,
            );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final screenSize = screenSizeForWidth(availableWidth);
            final cardMaxWidth = _cardMaxWidth(
              screenSize,
              isPortrait: _isPortraitLayout,
              availableWidth: availableWidth,
            );
            final outerPadding = switch (screenSize) {
              ScreenSize.compact => 12.0,
              ScreenSize.medium => 20.0,
              ScreenSize.expanded => 28.0,
            };
            final cardPadding = switch (screenSize) {
              ScreenSize.compact => const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              ScreenSize.medium => const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 20,
              ),
              ScreenSize.expanded => const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 24,
              ),
            };
            final headerSpacing = switch ((screenSize, _isPortraitLayout)) {
              (ScreenSize.compact, true) => 14.0,
              (ScreenSize.compact, false) => 12.0,
              (_, true) => 18.0,
              (_, false) => 14.0,
            };
            final footerSpacing = switch ((screenSize, _isPortraitLayout)) {
              (ScreenSize.compact, true) => 4.0,
              (_, true) => 10.0,
              _ => 12.0,
            };
            final useWideActionRail =
                !_isPortraitLayout && screenSize != ScreenSize.compact;

            final shouldCenter = _isPortraitLayout || _forceCenteredLayout;
            final columnMainAxis = shouldCenter
                ? MainAxisAlignment.center
                : MainAxisAlignment.start;
            final columnSize = shouldCenter
                ? MainAxisSize.max
                : MainAxisSize.min;

            final cardContent = DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: columnMainAxis,
                  mainAxisSize: columnSize,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          headerLabel,
                          style: headerStyle,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(height: headerSpacing),
                    if (primaryOfficials.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'Officials not posted.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: textColor,
                          ),
                        ),
                      )
                    else
                      _OfficialsLayout(
                        officials: primaryOfficials,
                        isPortrait: _isPortraitLayout,
                        textColor: textColor,
                      ),
                    SizedBox(height: footerSpacing),
                    if (alternate.isNotEmpty)
                      Text(
                        'Alternate: ${alternate.join(', ')}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                  ],
                ),
              ),
            );

            final displayCard = _isPortraitLayout
                ? AspectRatio(
                    aspectRatio: _portraitAspectRatio,
                    child: cardContent,
                  )
                : AspectRatio(
                    aspectRatio: _landscapeAspectRatio,
                    child: cardContent,
                  );

            final exportableCard = RepaintBoundary(
              key: _exportKey,
              child: displayCard,
            );

            final cardWrapper = SingleChildScrollView(
              padding: EdgeInsets.all(outerPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardMaxWidth),
                  child: exportableCard,
                ),
              ),
            );

            final canExport = true;
            final exportButton = _ExportButton(
              isBusy: _isExporting,
              label: kIsWeb ? 'Download PNG' : 'Export',
              onPressed: _isExporting || !canExport
                  ? null
                  : () => _exportImage(
                      targetSize: _isPortraitLayout
                          ? _portraitExportSize
                          : _landscapeExportSize,
                    ),
              expand: false,
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
              expand: false,
            );
            final wasExportButton = _ExportButton(
              isBusy: _isExporting,
              label: kIsWeb ? 'Download WAS PNG' : 'Export WAS',
              onPressed: _isExporting || !canExport
                  ? null
                  : () => _exportImage(
                      targetSize: _wasExportSize,
                      contentSize: _wasContentSize,
                    ),
              expand: false,
            );

            final bodyContent = useWideActionRail
                ? Row(
                    children: [
                      Expanded(child: cardWrapper),
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
                              children: [
                                rotateButton,
                                const SizedBox(height: 12),
                                exportButton,
                                const SizedBox(height: 12),
                                wasExportButton,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : !_isPortraitLayout
                ? Column(
                    children: [
                      Expanded(child: cardWrapper),
                      const SizedBox(height: 20),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              rotateButton,
                              const SizedBox(width: 12),
                              exportButton,
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: cardWrapper),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: Align(
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              rotateButton,
                              const SizedBox(height: 12),
                              exportButton,
                              const SizedBox(height: 12),
                              wasExportButton,
                            ],
                          ),
                        ),
                      ),
                    ],
                  );

            return Stack(
              children: [
                bodyContent,
                Positioned(
                  top: 8,
                  left: 8,
                  child: _BackButton(backgroundColor: backgroundColor),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _cardMaxWidth(
    ScreenSize screenSize, {
    required bool isPortrait,
    required double availableWidth,
  }) {
    if (screenSize == ScreenSize.compact) {
      return availableWidth;
    }
    if (isPortrait) {
      return screenSize == ScreenSize.medium ? 560 : 620;
    }
    return screenSize == ScreenSize.medium ? 760 : 920;
  }

  Future<void> _exportImage({
    required Size targetSize,
    Size? contentSize,
  }) async {
    final needsCentering = targetSize == _landscapeExportSize;
    var centeringApplied = false;
    if (needsCentering && !_forceCenteredLayout) {
      if (mounted) {
        setState(() {
          _forceCenteredLayout = true;
        });
        centeringApplied = true;
        await WidgetsBinding.instance.endOfFrame;
      }
    }

    final boundary =
        _exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      _showSnackBar('Unable to locate layout for export.');
      if (centeringApplied && mounted) {
        setState(() => _forceCenteredLayout = false);
      }
      return;
    }
    final size = boundary.size;
    if (size.width == 0 || size.height == 0) {
      _showSnackBar('Export failed: layout not ready.');
      if (centeringApplied && mounted) {
        setState(() => _forceCenteredLayout = false);
      }
      return;
    }
    setState(() => _isExporting = true);
    try {
      final widthRatio = targetSize.width / size.width;
      final heightRatio = targetSize.height / size.height;
      double pixelRatio = widthRatio > heightRatio ? widthRatio : heightRatio;
      if (pixelRatio < 1.0) {
        pixelRatio = 1.0;
      }
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      await _saveImage(image, targetSize: targetSize, contentSize: contentSize);
      image.dispose();
    } catch (e) {
      _showSnackBar('Export failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          if (centeringApplied) {
            _forceCenteredLayout = false;
          }
        });
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

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.isBusy,
    required this.onPressed,
    required this.label,
    this.expand = false,
  });

  final bool isBusy;
  final VoidCallback? onPressed;
  final String label;
  final bool expand;

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

    final button = ElevatedButton(onPressed: onPressed, child: child);
    if (expand) {
      return SizedBox(width: double.infinity, child: button);
    }
    return SizedBox(width: 160, child: button);
  }
}

class _OfficialsLayout extends StatelessWidget {
  const _OfficialsLayout({
    required this.officials,
    required this.isPortrait,
    required this.textColor,
  });

  final List<RefereeOfficial> officials;
  final bool isPortrait;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    if (isPortrait) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth && constraints.maxWidth > 0
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width;
          final availableHeight =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : double.infinity;
          final baseSize = (width * 0.32).clamp(104.0, 160.0);
          double portraitSize = baseSize;
          if (availableHeight.isFinite) {
            const verticalSpacing = 12.0;
            const textAllowance = 56.0;
            final totalSpacing = verticalSpacing * (officials.length - 1);
            final perOfficial =
                (availableHeight - totalSpacing) / officials.length;
            final adjusted = perOfficial - textAllowance;
            if (adjusted.isFinite && adjusted > 48) {
              portraitSize = adjusted.clamp(84.0, baseSize);
            }
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: officials.map((official) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: OfficialAvatar(
                  official: official,
                  size: portraitSize,
                  compact: true,
                  textColor: textColor,
                ),
              );
            }).toList(),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = screenSizeForWidth(constraints.maxWidth);
        final avatarSize = switch (screenSize) {
          ScreenSize.compact => 132.0,
          ScreenSize.medium => 148.0,
          ScreenSize.expanded => 160.0,
        };
        final spacing = switch (screenSize) {
          ScreenSize.compact => 16.0,
          ScreenSize.medium => 20.0,
          ScreenSize.expanded => 24.0,
        };
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: spacing,
          children: officials
              .map(
                (official) => OfficialAvatar(
                  official: official,
                  size: avatarSize,
                  compact: false,
                  textColor: textColor,
                ),
              )
              .toList(),
        );
      },
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
