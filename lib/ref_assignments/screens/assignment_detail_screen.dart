import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../assignment_export.dart';
import '../models.dart';
import '../responsive.dart';

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

  bool _isExporting = false;
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
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final previewFormat = _isPortraitLayout
        ? AssignmentExportFormat.portrait
        : AssignmentExportFormat.landscape;
    final previewSize = assignmentCanvasSize(previewFormat);

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
                    child: AssignmentExportPreview(
                      assignment: widget.assignment,
                      format: previewFormat,
                      backgroundColor: backgroundColor,
                      textColor: textColor,
                    ),
                  ),
                ),
              ),
            );

            final rotateButton = _ActionButton(
              label: _isPortraitLayout ? 'Rotate Landscape' : 'Rotate Portrait',
              isBusy: false,
              onPressed: _isExporting
                  ? null
                  : () {
                      setState(() {
                        _isPortraitLayout = !_isPortraitLayout;
                      });
                    },
            );
            final exportButton = _ActionButton(
              label: assignmentExportButtonLabel(previewFormat),
              isBusy: _isExporting,
              onPressed: _isExporting
                  ? null
                  : () => _runExport(
                      previewFormat == AssignmentExportFormat.landscape
                          ? AssignmentExportFormat.landscape
                          : AssignmentExportFormat.portrait,
                      backgroundColor,
                    ),
            );
            final wasButton = _ActionButton(
              label: assignmentExportButtonLabel(AssignmentExportFormat.was),
              isBusy: _isExporting,
              onPressed: _isExporting
                  ? null
                  : () =>
                        _runExport(AssignmentExportFormat.was, backgroundColor),
            );

            final actions = <Widget>[
              rotateButton,
              const SizedBox(height: 12),
              exportButton,
              const SizedBox(height: 12),
              wasButton,
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
                              children: actions,
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
                          children: actions,
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

  Future<void> _runExport(
    AssignmentExportFormat format,
    Color backgroundColor,
  ) async {
    setState(() => _isExporting = true);
    try {
      await exportAssignmentImage(
        context,
        assignment: widget.assignment,
        format: format,
        backgroundColor: backgroundColor,
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final bool isBusy;
  final VoidCallback? onPressed;

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
