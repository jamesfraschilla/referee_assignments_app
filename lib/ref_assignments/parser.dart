import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';

import 'models.dart';

class RefereeAssignmentParser {
  RefereeAssignmentsDay parseFromApi(
    Map<String, dynamic> data, {
    DateTime? fallbackDate,
  }) {
    final nbaSection = data['nba'];
    final games = <RefereeGameAssignment>[];
    DateTime? parsedDate;

    if (nbaSection is Map<String, dynamic>) {
      final table = nbaSection['Table'];
      if (table is Map<String, dynamic>) {
        final rows = table['rows'];
        if (rows is List) {
          for (final item in rows) {
            if (item is! Map<String, dynamic>) continue;
            parsedDate ??= _parseApiDate(item['game_date'] as String?);
            final assignment = _parseApiGameRow(item);
            if (assignment != null) {
              games.add(assignment);
            }
          }
        }
      }
    }

    final replayCrew = _parseReplayCenterFromApi(
      (nbaSection is Map<String, dynamic>) ? nbaSection['Table1'] : null,
    );

    final assignmentDate = parsedDate ?? fallbackDate ?? DateTime.now();
    return RefereeAssignmentsDay(
      date: assignmentDate,
      fetchedAt: DateTime.now().toUtc(),
      games: games,
      replayCenterCrew: replayCrew,
    );
  }

  RefereeAssignmentsDay parse(String html) {
    final document = html_parser.parse(html);

    final nbaArticle = document.querySelector(
      'article.post.referee-assignments',
    );
    if (nbaArticle == null) {
      throw const FormatException('Unable to locate NBA assignments section.');
    }

    final date = _parseDate(
      nbaArticle.querySelector('.entry-meta')?.text.trim() ?? '',
    );
    final table = nbaArticle.querySelector(
      '.nba-refs-content table',
    );
    if (table == null) {
      throw const FormatException('Unable to locate assignment table.');
    }

    final headerCells = table
        .querySelectorAll('thead tr th')
        .map((cell) => _cleanText(cell.text))
        .toList();
    final rows = table.querySelectorAll('tbody tr');

    final games = <RefereeGameAssignment>[];
    for (final row in rows) {
      final columns = row.querySelectorAll('td');
      if (columns.length < 2) continue;
      final rawMatchup = _cleanText(columns[0].text);
      if (rawMatchup.isEmpty) continue;

      final matchup = _splitMatchup(rawMatchup);
      final officials = <RefereeOfficial>[];
      for (var index = 1;
          index < columns.length && index < headerCells.length;
          index++) {
        final roleHeader = headerCells[index];
        if (roleHeader.toLowerCase().contains('game')) {
          continue;
        }
        final role = officialRoleFromHeader(roleHeader);
        final cell = columns[index];
        final official = _parseOfficial(cell, role);
        if (official != null) {
          officials.add(official);
        }
      }

      if (officials.isEmpty) continue;
      games.add(
        RefereeGameAssignment(
          rawMatchup: rawMatchup,
          visitorTeam: matchup.$1,
          homeTeam: matchup.$2,
          officials: officials,
        ),
      );
    }

    final replayCenterText = nbaArticle
        .querySelector('.replay-center-assignment')
        ?.text
        .trim();
    final replayCrew = _parseReplayCenter(replayCenterText);

    return RefereeAssignmentsDay(
      date: date,
      fetchedAt: DateTime.now().toUtc(),
      games: games,
      replayCenterCrew: replayCrew,
    );
  }

  DateTime _parseDate(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return DateTime.now();
    }
    final formats = <DateFormat>[
      DateFormat.yMMMMd('en_US'),
      DateFormat('MMMM d, yyyy', 'en_US'),
      DateFormat('MMM d, yyyy', 'en_US'),
    ];
    for (final format in formats) {
      try {
        return format.parse(normalized);
      } on FormatException {
        continue;
      }
    }
    return DateTime.now();
  }

  (String, String) _splitMatchup(String rawMatchup) {
    final sanitized = rawMatchup.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (sanitized.contains('@')) {
      final parts = sanitized.split('@');
      if (parts.length >= 2) {
        return (parts[0].trim(), parts[1].trim());
      }
    }
    if (sanitized.toLowerCase().contains(' vs ')) {
      final parts =
          sanitized.split(RegExp(r'\s+vs\.?\s+', caseSensitive: false));
      if (parts.length >= 2) {
        return (parts[0].trim(), parts[1].trim());
      }
    }
    return (sanitized, '');
  }

  RefereeOfficial? _parseOfficial(dom.Element cell, OfficialRole role) {
    final raw = _cleanText(cell.text);
    if (raw.isEmpty) return null;

    final numberPattern = RegExp(r'\(#?(\d+)\)');
    final match = numberPattern.firstMatch(raw);
    final number = match != null ? int.tryParse(match.group(1) ?? '') : null;
    final name = raw.replaceAll(numberPattern, '').trim();
    if (name.isEmpty || name == '-') {
      return null;
    }

    return RefereeOfficial(
      role: role,
      name: name,
      number: number,
    );
  }

  List<String> _parseReplayCenter(String? text) {
    if (text == null || text.isEmpty) return const [];
    final lower = text.toLowerCase();
    final cleaned = lower.startsWith('replay center')
        ? text.substring(text.indexOf(':') + 1)
        : text;
    return cleaned
        .split(',')
        .map((name) => _cleanText(name))
        .where((name) => name.isNotEmpty)
        .toList();
  }

  List<String> _parseReplayCenterFromApi(dynamic table) {
    if (table is! Map<String, dynamic>) return const [];
    final rows = table['rows'];
    if (rows is! List) return const [];
    final crew = <String>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final name = _cleanText(row['replaycenter_official'] as String?);
      if (name.isEmpty) continue;
      if (!crew.contains(name)) {
        crew.add(name);
      }
    }
    return crew;
  }

  RefereeGameAssignment? _parseApiGameRow(Map<String, dynamic> row) {
    final visitorTeam = _cleanText(row['away_team'] as String?);
    final homeTeam = _cleanText(row['home_team'] as String?);
    final rawMatchup = [
      if (visitorTeam.isNotEmpty) visitorTeam,
      if (homeTeam.isNotEmpty) homeTeam,
    ].join(' @ ');
    if (rawMatchup.isEmpty) return null;

    final officials = <RefereeOfficial>[];
    final official1 = _officialFromApi(
      row,
      nameKey: 'official1',
      numberKey: 'official1_JNum',
      role: OfficialRole.crewChief,
    );
    if (official1 != null) officials.add(official1);

    final official2 = _officialFromApi(
      row,
      nameKey: 'official2',
      numberKey: 'official2_JNum',
      role: OfficialRole.referee,
    );
    if (official2 != null) officials.add(official2);

    final official3 = _officialFromApi(
      row,
      nameKey: 'official3',
      numberKey: 'official3_JNum',
      role: OfficialRole.umpire,
    );
    if (official3 != null) officials.add(official3);

    final official4 = _officialFromApi(
      row,
      nameKey: 'official4',
      numberKey: 'official4_JNum',
      role: OfficialRole.alternate,
    );
    if (official4 != null) officials.add(official4);

    if (officials.isEmpty) return null;

    return RefereeGameAssignment(
      rawMatchup: rawMatchup,
      visitorTeam: visitorTeam,
      homeTeam: homeTeam,
      officials: officials,
    );
  }

  RefereeOfficial? _officialFromApi(
    Map<String, dynamic> row, {
    required String nameKey,
    required String numberKey,
    required OfficialRole role,
  }) {
    final name = _cleanText(row[nameKey] as String?);
    if (name.isEmpty || name.toLowerCase() == 'null') return null;
    final numberRaw = row[numberKey];
    int? number;
    if (numberRaw is int) {
      number = numberRaw;
    } else if (numberRaw is String) {
      number = int.tryParse(numberRaw);
    }
    return RefereeOfficial(role: role, name: name, number: number);
  }

  String _cleanText(String? input) {
    if (input == null) return '';
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  DateTime? _parseApiDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateFormat('MM/dd/yyyy', 'en_US').parse(raw);
    } on FormatException {
      return null;
    }
  }
}
