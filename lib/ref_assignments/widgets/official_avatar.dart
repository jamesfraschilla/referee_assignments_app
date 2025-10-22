import 'package:flutter/material.dart';

import '../models.dart';
import '../photo_resolver.dart';

class OfficialAvatar extends StatelessWidget {
  const OfficialAvatar({
    super.key,
    required this.official,
    this.size = 120,
    this.showRole = true,
  });

  final RefereeOfficial official;
  final double size;
  final bool showRole;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleLabel = officialRoleLabel(official.role);
    final textTheme = theme.textTheme;
    final borderRadius = BorderRadius.circular(16);
    final nameParts = _NameParts.from(official.name);
    final lineOneSegments = <String>[
      if (official.number != null) '#${official.number}',
      if (nameParts.first.isNotEmpty) nameParts.first,
    ];
    final lineOne = lineOneSegments.isNotEmpty
        ? lineOneSegments.join(' ')
        : nameParts.fallback;
    final lineTwo = nameParts.last;
    final lineOneStyle = (textTheme.headlineSmall ??
            textTheme.titleLarge ??
            textTheme.titleMedium ??
            const TextStyle(fontSize: 24))
        .copyWith(
      fontWeight: FontWeight.w700,
      color: Colors.black,
      fontFamily: 'DINalt',
    );
    final lineTwoStyle = (textTheme.titleMedium ??
            textTheme.titleSmall ??
            const TextStyle(fontSize: 18))
        .copyWith(
      fontWeight: FontWeight.w600,
      color: Colors.black,
      fontFamily: 'DINalt',
    );
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: size,
            width: size,
            child: Card(
              elevation: 4,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: borderRadius),
              child: ClipRRect(
                borderRadius: borderRadius,
                child: Image.asset(
                  refereeAssetPath(official.name),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Text(
                        _initials(official.name),
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            lineOne,
            textAlign: TextAlign.center,
            style: lineOneStyle,
          ),
          if (lineTwo.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              lineTwo,
              textAlign: TextAlign.center,
              style: lineTwoStyle,
            ),
          ],
          if (showRole) ...[
            const SizedBox(height: 4),
            Text(
              roleLabel,
              style: textTheme.labelLarge?.copyWith(
                color: const Color(0xFF565656),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    final first = words.first;
    final second = words.length > 1 ? words.last : '';
    var buffer = '';
    if (first.isNotEmpty) buffer += first[0];
    if (second.isNotEmpty) buffer += second[0];
    if (buffer.isEmpty && name.isNotEmpty) {
      buffer = name[0];
    }
    return buffer.toUpperCase();
  }
}

class _NameParts {
  const _NameParts({
    required this.first,
    required this.last,
    required this.fallback,
  });

  final String first;
  final String last;
  final String fallback;

  factory _NameParts.from(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return const _NameParts(first: '', last: '', fallback: '');
    }
    final parts =
        trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length == 1) {
      final upper = parts.first.toUpperCase();
      return _NameParts(first: upper, last: '', fallback: upper);
    }
    final first = parts.first.toUpperCase();
    final last = parts.sublist(1).join(' ').toUpperCase();
    return _NameParts(
      first: first,
      last: last,
      fallback: '$first $last'.trim(),
    );
  }
}
