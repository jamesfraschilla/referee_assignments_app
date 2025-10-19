import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
  static const _cacheFileName = 'referee_assignments.json';

  final http.Client _client;
  final RefereeAssignmentParser _parser = RefereeAssignmentParser();

  RefereeAssignmentsDay? _memoryCache;
  Future<File>? _cachedFile;
  Future<RefereeAssignmentsDay>? _ongoingFetch;

  Future<RefereeAssignmentsDay?> loadCachedDay() async {
    if (kIsWeb) {
      return _memoryCache;
    }
    try {
      final file = await _ensureCacheFile();
      if (!await file.exists()) {
        return null;
      }
      final raw = await file.readAsString();
      if (raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final day = RefereeAssignmentsDay.fromJson(map);
      _memoryCache = day;
      return day;
    } catch (e) {
      debugPrint('Failed to load cached assignments: $e');
      return null;
    }
  }

  Future<RefereeAssignmentsDay> fetchAndCache() async {
    if (_ongoingFetch != null) {
      return _ongoingFetch!;
    }
    final completer = Completer<RefereeAssignmentsDay>();
    _ongoingFetch = completer.future;
    try {
      final targetDate = DateTime.now();
      RefereeAssignmentsDay parsed;
      try {
        parsed = await _fetchFromApi(targetDate);
      } catch (apiError, apiStack) {
        debugPrint('Assignments API fetch failed: $apiError\n$apiStack');
        parsed = await _fetchFromHtml();
      }
      await _saveCache(parsed);
      _memoryCache = parsed;
      completer.complete(parsed);
      return parsed;
    } catch (e, stack) {
      debugPrint('Assignments fetch failed: $e\n$stack');
      completer.completeError(e, stack);
      rethrow;
    } finally {
      _ongoingFetch = null;
    }
  }

  Future<RefereeAssignmentsDay> _fetchFromApi(DateTime targetDate) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(targetDate);
    final uri = Uri.parse('$_apiEndpoint?date=$formattedDate');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to load assignments API: HTTP ${response.statusCode}',
        uri: uri,
      );
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
      throw HttpException(
        'Failed to load assignments page: HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    return _parser.parse(response.body);
  }

  Future<void> _saveCache(RefereeAssignmentsDay day) async {
    if (kIsWeb) {
      _memoryCache = day;
      return;
    }
    try {
      final file = await _ensureCacheFile();
      await file.writeAsString(jsonEncode(day.toJson()));
    } catch (e) {
      debugPrint('Failed to persist assignments: $e');
    }
  }

  Future<File> _ensureCacheFile() async {
    if (_cachedFile != null) {
      return _cachedFile!;
    }
    _cachedFile = _createCacheFile();
    return _cachedFile!;
  }

  Future<File> _createCacheFile() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, _cacheFileName));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<void> dispose() async {
    if (!kIsWeb) {
      try {
        _client.close();
      } catch (_) {
        // Ignore.
      }
    }
  }
}
