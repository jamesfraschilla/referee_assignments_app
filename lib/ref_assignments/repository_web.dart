import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'models.dart';
import 'parser.dart';

class RefereeAssignmentsRepository {
  RefereeAssignmentsRepository({http.Client? client})
      : _client = client ?? http.Client();

  static final RefereeAssignmentsRepository instance =
      RefereeAssignmentsRepository();

  static const _endpoint =
      'https://official.nba.com/referee-assignments/';
  static const _apiEndpoint =
      'https://official.nba.com/wp-json/api/v1/get-game-officials';

  final http.Client _client;
  final RefereeAssignmentParser _parser = RefereeAssignmentParser();

  RefereeAssignmentsDay? _memoryCache;
  final Map<String, RefereeAssignmentsDay> _memoryHistory = {};
  Future<RefereeAssignmentsDay>? _ongoingFetch;

  Future<RefereeAssignmentsDay?> loadCachedDay({DateTime? date}) async {
    final targetDate = _normalizeDate(date);
    final cacheKey = targetDate?.toIso8601String();
    if (cacheKey != null && _memoryHistory.containsKey(cacheKey)) {
      return _memoryHistory[cacheKey];
    }
    return targetDate == null ? _memoryCache : _memoryHistory[cacheKey];
  }

  Future<RefereeAssignmentsDay> fetchAndCache({DateTime? date}) async {
    if (_ongoingFetch != null) {
      return _ongoingFetch!;
    }
    final completer = Completer<RefereeAssignmentsDay>();
    _ongoingFetch = completer.future;
    try {
      final targetDate = _normalizeDate(date) ?? DateTime.now();
      RefereeAssignmentsDay parsed;
      try {
        parsed = await _fetchFromApi(targetDate);
        if (parsed.games.isEmpty) {
          parsed = await _fetchFromHtml();
        }
      } catch (_) {
        parsed = await _fetchFromHtml();
      }
      final normalizedDay = _normalizeAssignmentsDay(parsed, targetDate);
      await _saveCache(normalizedDay);
      await _saveHistory(normalizedDay);
      completer.complete(normalizedDay);
      return normalizedDay;
    } catch (e, stack) {
      completer.completeError(e, stack);
      rethrow;
    } finally {
      _ongoingFetch = null;
    }
  }

  Future<RefereeAssignmentsDay> _fetchFromApi(DateTime targetDate) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(targetDate);
    final uri = Uri.parse('$_apiEndpoint?date=$formattedDate');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load assignments API: HTTP ${response.statusCode}');
    }
    final body = response.body;
    final map = jsonDecode(body);
    if (map is! Map<String, dynamic>) {
      throw const FormatException('Unexpected assignments API response.');
    }
    return _parser.parseFromApi(map, fallbackDate: targetDate);
  }

  Future<RefereeAssignmentsDay> _fetchFromHtml() async {
    final uri = Uri.parse(_endpoint);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load assignments page: HTTP ${response.statusCode}');
    }
    return _parser.parse(response.body);
  }

  Future<void> _saveCache(RefereeAssignmentsDay day) async {
    _memoryCache = day;
  }

  Future<void> _saveHistory(RefereeAssignmentsDay day) async {
    _memoryHistory[day.date.toIso8601String()] = day;
  }

  Future<RefereeAssignmentsDay?> loadOrFetchDay(DateTime date) async {
    final cached = await loadCachedDay(date: date);
    if (cached != null) {
      return cached;
    }
    try {
      return await fetchAndCache(date: date);
    } catch (_) {
      return null;
    }
  }

  Future<List<DateTime>> listCachedDates() async {
    final dates = <DateTime>{};
    if (_memoryCache != null) {
      dates.add(_normalizeDate(_memoryCache!.date)!);
    }
    dates.addAll(
      _memoryHistory.values.map((day) => _normalizeDate(day.date)!),
    );
    final sorted = dates.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  DateTime? _normalizeDate(DateTime? date) {
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> dispose() async {
    try {
      _client.close();
    } catch (_) {
      // Ignore.
    }
  }

  RefereeAssignmentsDay _normalizeAssignmentsDay(
    RefereeAssignmentsDay day,
    DateTime targetDate,
  ) {
    final normalizedDate = _normalizeDate(day.date) ?? targetDate;
    if (normalizedDate == day.date && day.fetchedAt.isUtc) {
      return day;
    }
    return RefereeAssignmentsDay(
      date: normalizedDate,
      fetchedAt: day.fetchedAt.isUtc ? day.fetchedAt : day.fetchedAt.toUtc(),
      games: day.games,
      replayCenterCrew: day.replayCenterCrew,
    );
  }
}
