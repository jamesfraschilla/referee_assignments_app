import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../widgets/official_avatar.dart';

const Size _portraitExportSize = Size(1536, 2592);
const Size _landscapeExportSize = Size(3300, 2550);
const double _portraitAspectRatio = 1536 / 2592;
const double _landscapeAspectRatio = 3300 / 2550;

class AssignmentDetailScreen extends StatefulWidget {
  const AssignmentDetailScreen({
    super.key,
    required this.assignment,
    required this.assignmentDate,
  });

  final RefereeGameAssignment assignment;
  final DateTime assignmentDate;

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  final GlobalKey _exportKey = GlobalKey();
  bool _isExporting = false;
  Color _latestBackgroundColor = Colors.black;
  bool _forceCenteredLayout = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
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
    final matchupLabel = assignment.displayMatchup.toUpperCase();
    final baseMatchupStyle = theme.textTheme.headlineMedium ??
        theme.textTheme.displaySmall ??
        theme.textTheme.titleLarge ??
        theme.textTheme.titleMedium;
    final matchupBaseSize = baseMatchupStyle?.fontSize ?? 32;
    final matchupStyle = (baseMatchupStyle ??
            const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ))
        .copyWith(
      fontWeight: FontWeight.bold,
      color: textColor,
      fontSize: matchupBaseSize * 1.3,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final orientation = MediaQuery.of(context).orientation;
            final isPortrait = orientation == Orientation.portrait;
            final availableWidth = constraints.maxWidth;
            final cardWidth = availableWidth * 0.95;
            final headerSpacing = isPortrait ? 14.0 : 12.0;
            final footerSpacing = isPortrait ? 4.0 : 12.0;

            final shouldCenter = isPortrait || _forceCenteredLayout;
            final columnMainAxis =
                shouldCenter ? MainAxisAlignment.center : MainAxisAlignment.start;
            final columnSize =
                shouldCenter ? MainAxisSize.max : MainAxisSize.min;

            final cardContent = DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
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
                          matchupLabel,
                          style: matchupStyle,
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
                        isPortrait: isPortrait,
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

            final displayCard = isPortrait
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
              padding: const EdgeInsets.all(12),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: availableWidth < 600 ? availableWidth : cardWidth,
                  ),
                  child: exportableCard,
                ),
              ),
            );

            final exportButton = _ExportButton(
              isBusy: _isExporting,
              onPressed: _isExporting
                  ? null
                  : () => _exportImage(
                        targetSize: isPortrait
                            ? _portraitExportSize
                            : _landscapeExportSize,
                      ),
              expand: false,
            );

            if (!isPortrait) {
              return Column(
                children: [
                  Expanded(child: cardWrapper),
                  const SizedBox(height: 20),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [exportButton],
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                Expanded(child: cardWrapper),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Align(
                    alignment: Alignment.center,
                    child: exportButton,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _exportImage({required Size targetSize}) async {
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
      await _saveImage(image, targetSize: targetSize);
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
  }) async {
    final int targetWidth = targetSize.width.toInt();
    final int targetHeight = targetSize.height.toInt();
    ui.Picture? picture;
    ui.Image? processed;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint();
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, targetSize.width, targetSize.height),
        paint..color = _latestBackgroundColor,
      );
      final widthScale = targetSize.width / image.width;
      double scaledWidth = targetSize.width;
      double scaledHeight = image.height * widthScale;
      double offsetX = 0;
      double offsetY = (targetSize.height - scaledHeight) / 2;
      if (scaledHeight > targetSize.height) {
        final heightScale = targetSize.height / image.height;
        scaledHeight = targetSize.height;
        scaledWidth = image.width * heightScale;
        offsetY = 0;
        offsetX = (targetSize.width - scaledWidth) / 2;
      }
      final src = ui.Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final dst = ui.Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight);
      canvas.drawImageRect(image, src, dst, Paint());
      picture = recorder.endRecording();
      processed = await picture.toImage(targetWidth, targetHeight);
      final byteData =
          await processed.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showSnackBar('Export failed: could not encode image.');
        return;
      }
      final pngBytes = byteData.buffer.asUint8List();
      final timestamp =
          DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      if (_isIosSimulator) {
        _showSnackBar('Preview exported. Photos app unavailable on simulator.');
        return;
      }
      final result = await ImageGallerySaver.saveImage(
        pngBytes,
        name: 'ref_assignment_$timestamp',
        isReturnImagePathOfIOS: true,
      );
      final success = _isSaveSuccessful(result);
      _showSnackBar(
        success ? 'Exported to Photos.' : 'Export failed while saving.',
      );
    } catch (e) {
      _showSnackBar('Export failed: $e');
    } finally {
      processed?.dispose();
      picture?.dispose();
    }
  }

  bool get _isIosSimulator {
    try {
      return io.Platform.isIOS &&
          io.Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');
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
    this.expand = false,
  });

  final bool isBusy;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: onPressed,
      child: isBusy
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
          : const Text('Export'),
    );

    if (expand) {
      return SizedBox(width: double.infinity, child: button);
    }

    return SizedBox(
      width: 160,
      child: button,
    );
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
          final availableHeight = constraints.hasBoundedHeight &&
                  constraints.maxHeight.isFinite
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

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 24,
      children: officials
          .map(
            (official) => OfficialAvatar(
              official: official,
              size: 160,
              compact: false,
              textColor: textColor,
            ),
          )
          .toList(),
    );
  }
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
