import 'package:flutter/material.dart';

import '../assignment_export.dart';
import '../models.dart';
import '../photo_resolver.dart';
import '../responsive.dart';

const double _previewAvatarSize = 64;

class AssignmentCard extends StatelessWidget {
  const AssignmentCard({super.key, required this.assignment, this.onTap});

  final RefereeGameAssignment assignment;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final officials = assignment.officials
        .where((official) => official.role != OfficialRole.alternate)
        .toList();
    final previewOfficials = officials.take(3).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final textTheme = theme.textTheme;
        final screenSize = screenSizeForWidth(constraints.maxWidth);
        final horizontalMargin = switch (screenSize) {
          ScreenSize.compact => 12.0,
          ScreenSize.medium => 16.0,
          ScreenSize.expanded => 20.0,
        };
        final contentPadding = switch (screenSize) {
          ScreenSize.compact => const EdgeInsets.fromLTRB(18, 16, 18, 12),
          ScreenSize.medium => const EdgeInsets.fromLTRB(22, 18, 22, 14),
          ScreenSize.expanded => const EdgeInsets.fromLTRB(24, 20, 24, 16),
        };

        return Card(
          margin: EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: 6,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    assignment.displayMatchup,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (previewOfficials.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _AssignmentPreviewRow(
                      officials: previewOfficials,
                      assignment: assignment,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AssignmentPreviewRow extends StatelessWidget {
  const _AssignmentPreviewRow({
    required this.officials,
    required this.assignment,
  });

  final List<RefereeOfficial> officials;
  final RefereeGameAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = screenSizeForWidth(constraints.maxWidth);
        final spacing = switch (screenSize) {
          ScreenSize.compact => 16.0,
          ScreenSize.medium => 24.0,
          ScreenSize.expanded => 32.0,
        };
        final wrap = Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: 12,
          children: officials
              .map(
                (official) =>
                    _OfficialPreview(official: official, nameStyle: textStyle),
              )
              .toList(),
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: wrap),
            const SizedBox(width: 12),
            _CardExportButtons(assignment: assignment),
          ],
        );
      },
    );
  }
}

class _OfficialPreview extends StatelessWidget {
  const _OfficialPreview({required this.official, required this.nameStyle});

  final RefereeOfficial official;
  final TextStyle? nameStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = _compactName(official.name);
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (_previewAvatarSize * devicePixelRatio)
        .clamp(1, double.infinity)
        .round();

    return SizedBox(
      width: _previewAvatarSize + 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              refereeAssetPath(official.name),
              height: _previewAvatarSize,
              width: _previewAvatarSize,
              cacheWidth: cacheWidth,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: _previewAvatarSize,
                  width: _previewAvatarSize,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials(official.name),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            displayName,
            style: nameStyle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _compactName(String raw) {
    final parts = raw
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return raw;
    if (parts.length == 1) return parts.first;
    final last = parts.removeLast();
    final first = parts.first;
    return '$first $last';
  }

  String _initials(String raw) {
    final parts = raw
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    final first = parts.first;
    final last = parts.length > 1 ? parts.last : '';
    final buffer = StringBuffer();
    if (first.isNotEmpty) buffer.write(first[0]);
    if (last.isNotEmpty) buffer.write(last[0]);
    final initials = buffer.toString();
    if (initials.isNotEmpty) {
      return initials.toUpperCase();
    }
    return raw.isNotEmpty ? raw[0].toUpperCase() : '';
  }
}

class _CardExportButtons extends StatefulWidget {
  const _CardExportButtons({required this.assignment});

  final RefereeGameAssignment assignment;

  @override
  State<_CardExportButtons> createState() => _CardExportButtonsState();
}

class _CardExportButtonsState extends State<_CardExportButtons> {
  AssignmentExportFormat? _activeFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.brightness == Brightness.dark
        ? Colors.black
        : Colors.white;
    const formats = [
      AssignmentExportFormat.portrait,
      AssignmentExportFormat.landscape,
      AssignmentExportFormat.was,
    ];

    return SizedBox(
      width: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < formats.length; index++) ...[
            _ExportMiniButton(
              label: assignmentExportButtonLabel(formats[index]),
              isBusy: _activeFormat == formats[index],
              onPressed: _activeFormat != null
                  ? null
                  : () => _runExport(formats[index], backgroundColor),
            ),
            if (index < formats.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Future<void> _runExport(
    AssignmentExportFormat format,
    Color backgroundColor,
  ) async {
    setState(() => _activeFormat = format);
    try {
      await exportAssignmentImage(
        context,
        assignment: widget.assignment,
        format: format,
        backgroundColor: backgroundColor,
      );
    } finally {
      if (mounted) {
        setState(() => _activeFormat = null);
      }
    }
  }
}

class _ExportMiniButton extends StatelessWidget {
  const _ExportMiniButton({
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
        ? const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label, textAlign: TextAlign.center, maxLines: 2);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          textStyle: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        child: child,
      ),
    );
  }
}
