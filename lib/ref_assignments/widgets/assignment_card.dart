import 'package:flutter/material.dart';

import '../models.dart';
import '../photo_resolver.dart';

const double _previewAvatarSize = 64;

class AssignmentCard extends StatelessWidget {
  const AssignmentCard({super.key, required this.assignment, this.onTap});

  final RefereeGameAssignment assignment;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final officials = assignment.officials
        .where((official) => official.role != OfficialRole.alternate)
        .toList();
    final previewOfficials = officials.take(3).toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
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
                _AssignmentPreviewRow(officials: previewOfficials),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentPreviewRow extends StatelessWidget {
  const _AssignmentPreviewRow({required this.officials});

  final List<RefereeOfficial> officials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: officials
          .map(
            (official) => _OfficialPreview(
              official: official,
              nameStyle: textStyle,
            ),
          )
          .toList(),
    );
  }
}

class _OfficialPreview extends StatelessWidget {
  const _OfficialPreview({
    required this.official,
    required this.nameStyle,
  });

  final RefereeOfficial official;
  final TextStyle? nameStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = _compactName(official.name);

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
