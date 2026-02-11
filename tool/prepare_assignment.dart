import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../lib/ref_assignments/models.dart';
import '../lib/ref_assignments/parser.dart';

const String _endpoint = 'https://official.nba.com/referee-assignments/';
const String _apiEndpoint =
    'https://official.nba.com/wp-json/api/v1/get-game-officials';

const Map<String, List<String>> _teamAliases = {
  'WAS': ['WAS', 'WASHINGTON', 'WIZARDS', 'WASHINGTON WIZARDS'],
};

Future<void> main() async {
  final teamId =
      (Platform.environment['TEAM_ID'] ?? Platform.environment['TEAM'] ?? '')
          .trim()
          .toUpperCase();
  if (teamId.isEmpty) {
    stderr.writeln('TEAM_ID is required.');
    exit(2);
  }

  final outputPath = Platform.environment['RENDER_CONFIG']?.trim().isNotEmpty ==
          true
      ? Platform.environment['RENDER_CONFIG']!.trim()
      : 'build/render_config.json';

  tz.initializeTimeZones();
  final location = tz.getLocation('America/New_York');
  final nowEastern = tz.TZDateTime.now(location);
  final easternDate = DateTime(nowEastern.year, nowEastern.month, nowEastern.day);

  final assignmentDay = await _fetchAssignments(easternDate);
  final aliases = _resolveAliases(teamId);
  final match = _findTeamGame(assignmentDay.games, aliases);

  if (match == null) {
    _writeOutputs(outputPath, shouldSend: false, reason: 'No game for $teamId');
    return;
  }

  final isAway = _isAwayGame(match, aliases);
  final format = isAway ? 'original_landscape' : 'was_portrait';
  final theme = isAway ? 'light' : 'dark';
  final targetSize = isAway ? const [3300, 2550] : const [3840, 2160];
  final contentSize = isAway ? null : const [802, 1300];

  final subject = isAway
      ? 'Referee Assignments: ${match.displayMatchup} (Away)'
      : 'Referee Assignments: ${match.displayMatchup} (Home)';
  final body = isAway
      ? 'Away game today. Attached is the referee assignments image.'
      : 'Home game today. Attached is the referee assignments image.';

  _writeOutputs(
    outputPath,
    shouldSend: true,
    assignment: match,
    date: easternDate,
    format: format,
    theme: theme,
    targetSize: targetSize,
    contentSize: contentSize,
    subject: subject,
    body: body,
  );
}

Future<RefereeAssignmentsDay> _fetchAssignments(DateTime date) async {
  final formattedDate = DateFormat('yyyy-MM-dd').format(date);
  final apiUri = Uri.parse('$_apiEndpoint?date=$formattedDate');
  final parser = RefereeAssignmentParser();

  try {
    final response = await http.get(
      apiUri,
      headers: {
        'Referer': _endpoint,
        'User-Agent':
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) FlutterAutomation/1.0',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final body = response.body;
      final map = jsonDecode(body);
      if (map is Map<String, dynamic>) {
        return parser.parseFromApi(map, fallbackDate: date);
      }
    }
  } catch (_) {
    // fall back to HTML
  }

  final htmlResponse = await http.get(Uri.parse(_endpoint));
  if (htmlResponse.statusCode != 200) {
    throw Exception('Failed to load assignments page.');
  }
  return parser.parse(htmlResponse.body);
}

RefereeGameAssignment? _findTeamGame(
  List<RefereeGameAssignment> games,
  List<String> aliases,
) {
  for (final game in games) {
    if (_matchesTeam(game.visitorTeam, aliases) ||
        _matchesTeam(game.homeTeam, aliases)) {
      return game;
    }
  }
  return null;
}

bool _isAwayGame(RefereeGameAssignment game, List<String> aliases) {
  return _matchesTeam(game.visitorTeam, aliases) &&
      !_matchesTeam(game.homeTeam, aliases);
}

bool _matchesTeam(String teamName, List<String> aliases) {
  if (teamName.trim().isEmpty) return false;
  final normalizedTeam = _normalize(teamName);
  for (final alias in aliases) {
    final normalizedAlias = _normalize(alias);
    if (normalizedTeam == normalizedAlias) return true;
    if (normalizedTeam.contains(normalizedAlias)) return true;
  }
  return false;
}

String _normalize(String value) {
  final upper = value.toUpperCase();
  return upper.replaceAll(RegExp(r'[^A-Z]'), ' ');
}

List<String> _resolveAliases(String teamId) {
  final override = Platform.environment['TEAM_ALIASES'];
  if (override != null && override.trim().isNotEmpty) {
    return override.split(',').map((value) => value.trim()).toList();
  }
  return _teamAliases[teamId] ?? [teamId];
}

void _writeOutputs(
  String outputPath, {
  required bool shouldSend,
  String? reason,
  RefereeGameAssignment? assignment,
  DateTime? date,
  String? format,
  String? theme,
  List<int>? targetSize,
  List<int>? contentSize,
  String? subject,
  String? body,
}) {
  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);

  final payload = <String, dynamic>{
    'shouldSend': shouldSend,
    if (reason != null) 'reason': reason,
    if (assignment != null) 'assignment': assignment.toJson(),
    if (date != null) 'date': date.toIso8601String(),
    if (format != null) 'format': format,
    if (theme != null) 'theme': theme,
    if (targetSize != null) 'targetSize': targetSize,
    if (contentSize != null) 'contentSize': contentSize,
    if (subject != null) 'subject': subject,
    if (body != null) 'body': body,
    'outputPath': 'build/assignment.png',
  };

  outputFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));

  stdout.writeln('should_send=${shouldSend ? 'true' : 'false'}');
  if (reason != null) {
    stdout.writeln('reason=$reason');
  }
  if (assignment != null) {
    stdout.writeln('matchup=${assignment.displayMatchup}');
  }
  if (date != null) {
    stdout.writeln('assignment_date=${date.toIso8601String()}');
  }

  final githubOutput = Platform.environment['GITHUB_OUTPUT'];
  if (githubOutput != null && githubOutput.isNotEmpty) {
    final file = File(githubOutput);
    file.writeAsStringSync(
      'should_send=${shouldSend ? 'true' : 'false'}\n',
      mode: FileMode.append,
    );
  }
}
