import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../widgets/official_avatar.dart';

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
  final GlobalKey _captureKey = GlobalKey();
  _ExportConfig? _exportConfig;
  bool _isSaving = false;

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
      color: Colors.black,
      fontSize: matchupBaseSize * 1.3,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _exportAssignment,
        icon: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.download),
        label: Text(_isSaving ? 'Saving...' : 'Save Photo'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final orientation = MediaQuery.of(context).orientation;
            final isPortrait = orientation == Orientation.portrait;
            final availableWidth = constraints.maxWidth;
            final cardWidth = availableWidth * 0.95;
            final headerSpacing = isPortrait ? 18.0 : 12.0;
            final footerSpacing = isPortrait ? 4.0 : 12.0;

            final displayCard = isPortrait
                ? AspectRatio(
                    aspectRatio: 9 / 16,
                    child: _buildAssignmentCard(
                      theme: theme,
                      matchupStyle: matchupStyle,
                      matchupLabel: matchupLabel,
                      primaryOfficials: primaryOfficials,
                      alternate: alternate,
                      isPortraitLayout: true,
                      headerSpacing: headerSpacing,
                      footerSpacing: footerSpacing,
                    ),
                  )
                : AspectRatio(
                    aspectRatio: 11 / 8.5,
                    child: _buildAssignmentCard(
                      theme: theme,
                      matchupStyle: matchupStyle,
                      matchupLabel: matchupLabel,
                      primaryOfficials: primaryOfficials,
                      alternate: alternate,
                      isPortraitLayout: false,
                      headerSpacing: headerSpacing,
                      footerSpacing: footerSpacing,
                    ),
                  );

            final layers = <Widget>[
              SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          availableWidth < 600 ? availableWidth : cardWidth,
                    ),
                    child: displayCard,
                  ),
                ),
              ),
            ];

            final exportConfig = _exportConfig;
            if (exportConfig != null) {
              final captureWidth = exportConfig.isPortrait ? 1080.0 : 1920.0;
              layers.add(
                IgnorePointer(
                  ignoring: true,
                  child: Center(
                    child: Opacity(
                      opacity: 0,
                      child: SizedBox(
                        width: captureWidth,
                        child: RepaintBoundary(
                          key: _captureKey,
                          child: AspectRatio(
                            aspectRatio: exportConfig.aspectRatio,
                            child: _buildAssignmentCard(
                              theme: theme,
                              matchupStyle: matchupStyle,
                              matchupLabel: matchupLabel,
                              primaryOfficials: primaryOfficials,
                              alternate: alternate,
                              isPortraitLayout: exportConfig.isPortrait,
                              headerSpacing:
                                  exportConfig.isPortrait ? 18.0 : 12.0,
                              footerSpacing:
                                  exportConfig.isPortrait ? 4.0 : 12.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Stack(children: layers);
          },
        ),
      ),
    );
  }

  Widget _buildAssignmentCard({
    required ThemeData theme,
    required TextStyle matchupStyle,
    required String matchupLabel,
    required List<RefereeOfficial> primaryOfficials,
    required List<String> alternate,
    required bool isPortraitLayout,
    required double headerSpacing,
    required double footerSpacing,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
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
                  style: theme.textTheme.titleMedium,
                ),
              )
            else
              _OfficialsLayout(
                officials: primaryOfficials,
                isPortrait: isPortraitLayout,
              ),
            SizedBox(height: footerSpacing),
            if (alternate.isNotEmpty)
              Text(
                'Alternate: ${alternate.join(', ')}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAssignment() async {
    if (kIsWeb) {
      _showSnackBar('Saving to Photos is not supported on the web.');
      return;
    }
    if (_isSaving) return;

    final orientation = MediaQuery.of(context).orientation;
    final isPortrait = orientation == Orientation.portrait;

    setState(() {
      _isSaving = true;
      _exportConfig = _ExportConfig(
        isPortrait: isPortrait,
        aspectRatio: isPortrait ? 9 / 16 : 16 / 9,
      );
    });

    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;

    try {
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Capture boundary unavailable.');
      }

      var attempt = 0;
      while (boundary.debugNeedsPaint && attempt < 5) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        await WidgetsBinding.instance.endOfFrame;
        attempt++;
      }
      if (boundary.debugNeedsPaint) {
        throw Exception('Capture target not ready to paint.');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? pngBytes = byteData?.buffer.asUint8List();
      if (pngBytes == null) {
        throw Exception('Failed to encode image.');
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final result = await ImageGallerySaver.saveImage(
        pngBytes,
        name: 'ref_assignment_$timestamp',
        quality: 100,
      );

      var success = false;
      if (result is Map) {
        success = result['isSuccess'] == true ||
            (result['errorMessage'] == null && result['filePath'] != null);
      } else if (result != null) {
        success = true;
      }

      if (!success) {
        throw Exception('Save failed: $result');
      }

      _showSnackBar('Saved to Photos');
    } catch (error) {
      debugPrint('Failed to save assignment image: $error');
      _showSnackBar('Could not save photo. Check permissions and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _exportConfig = null;
          _isSaving = false;
        });
      } else {
        _exportConfig = null;
        _isSaving = false;
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ExportConfig {
  const _ExportConfig({
    required this.isPortrait,
    required this.aspectRatio,
  });

  final bool isPortrait;
  final double aspectRatio;
}

class _OfficialsLayout extends StatelessWidget {
  const _OfficialsLayout({
    required this.officials,
    required this.isPortrait,
  });

  final List<RefereeOfficial> officials;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    if (isPortrait) {
      final width = MediaQuery.of(context).size.width;
      final portraitSize = width < 360 ? 120.0 : 130.0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: officials.map((official) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: OfficialAvatar(
              official: official,
              size: portraitSize,
              compact: true,
            ),
          );
        }).toList(),
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
