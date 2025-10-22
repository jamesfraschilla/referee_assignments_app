import 'package:flutter/material.dart';

import '../models.dart';
import '../photo_resolver.dart';

class OfficialAvatar extends StatelessWidget {
  const OfficialAvatar({
    super.key,
    required this.official,
    this.size = 120,
    this.showRole = true,
    this.compact = false,
  });

  final RefereeOfficial official;
  final double size;
  final bool showRole;
  final bool compact;

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
      if (compact && nameParts.last.isNotEmpty) nameParts.last,
    ];
    final lineOne = lineOneSegments.isNotEmpty
        ? lineOneSegments.join(' ')
        : nameParts.fallback;
    final lineTwo = compact ? '' : nameParts.last;
    final baseLineOneStyle = (textTheme.headlineSmall ??
            textTheme.titleLarge ??
            textTheme.titleMedium ??
            const TextStyle(fontSize: 24));
    final lineOneStyle = baseLineOneStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: Colors.black,
      fontFamily: 'DINalt',
      height: compact ? 0.85 : 1.05,
      fontSize: compact
          ? (baseLineOneStyle.fontSize ?? 24) * 0.9
          : baseLineOneStyle.fontSize,
    );
    final lineTwoStyle = (textTheme.titleMedium ??
            textTheme.titleSmall ??
            const TextStyle(fontSize: 18))
        .copyWith(
      fontWeight: FontWeight.w600,
      color: Colors.black,
      fontFamily: 'DINalt',
      height: compact ? 0.9 : 1.05,
    );
    final photoSpacing = compact ? 4.0 : 12.0;
    final lineGap = compact ? 0.0 : 2.0;
    final roleGap = compact ? 0.0 : 4.0;
    final body = <Widget>[
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
    ];

    if (compact) {
      body.add(SizedBox(height: photoSpacing));
      body.add(Text(
        lineOne,
        textAlign: TextAlign.center,
        style: lineOneStyle,
        softWrap: true,
      ));
    } else {
      body.addAll([
        SizedBox(height: photoSpacing),
        Text(
          lineOne,
          textAlign: TextAlign.center,
          style: lineOneStyle,
        ),
        if (lineTwo.isNotEmpty) ...[
          SizedBox(height: lineGap),
          Text(
            lineTwo,
            textAlign: TextAlign.center,
            style: lineTwoStyle,
          ),
        ],
      ]);
    }

    if (showRole) {
      body.addAll([
        SizedBox(height: roleGap),
        Text(
          roleLabel,
          textAlign: TextAlign.center,
          style: textTheme.labelLarge?.copyWith(
            color: const Color(0xFF565656),
            fontWeight: FontWeight.w600,
          ),
        ),
      ]);
    }

    return SizedBox(
      width: compact ? double.infinity : size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: body,
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
