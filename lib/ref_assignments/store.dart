import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'repository.dart';

enum RefereeAssignmentsStatus { idle, loading, ready, error }

class RefereeAssignmentsState {
  const RefereeAssignmentsState({
    required this.status,
    required this.day,
    required this.isRefreshing,
    required this.availableDates,
    this.selectedDate,
    this.error,
  });

  final RefereeAssignmentsStatus status;
  final RefereeAssignmentsDay? day;
  final bool isRefreshing;
  final List<DateTime> availableDates;
  final DateTime? selectedDate;
  final Object? error;

  RefereeAssignmentsState copyWith({
    RefereeAssignmentsStatus? status,
    RefereeAssignmentsDay? day,
    bool? isRefreshing,
    List<DateTime>? availableDates,
    DateTime? selectedDate,
    Object? error,
    bool keepError = false,
  }) {
    return RefereeAssignmentsState(
      status: status ?? this.status,
      day: day ?? this.day,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      availableDates: availableDates ?? this.availableDates,
      selectedDate: selectedDate ?? this.selectedDate,
      error: keepError ? error ?? this.error : error,
    );
  }

  static RefereeAssignmentsState initial() => const RefereeAssignmentsState(
        status: RefereeAssignmentsStatus.idle,
        day: null,
        isRefreshing: false,
        availableDates: <DateTime>[],
      );
}

class RefereeAssignmentsStore extends ChangeNotifier {
  RefereeAssignmentsStore({RefereeAssignmentsRepository? repository})
      : _repository = repository ?? RefereeAssignmentsRepository.instance,
        _state = RefereeAssignmentsState.initial();

  final RefereeAssignmentsRepository _repository;
  RefereeAssignmentsState _state;
  bool _isFetching = false;

  RefereeAssignmentsState get state => _state;


  DateTime get _selectedDate =>
      _state.selectedDate ?? _normalizeDate(DateTime.now());

  Future<void> loadInitial() async {
    if (_state.status != RefereeAssignmentsStatus.idle) return;
    final today = _normalizeDate(DateTime.now());
    await _setSelectedDate(today);
    await _refreshSelected();
  }

  Future<void> refresh() => _refreshSelected();

  Future<void> selectDate(DateTime date) async {
    final normalized = _normalizeDate(date);
    if (_state.selectedDate == normalized && !_state.isRefreshing) {
      return;
    }
    await _setSelectedDate(normalized);
    await _refreshSelected();
  }

  void _updateState(RefereeAssignmentsState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> _setSelectedDate(DateTime date) async {
    final normalized = _normalizeDate(date);
    final cached = await _repository.loadCachedDay(date: normalized);
    final availableDates = await _repository.listCachedDates();
    final combinedDates = _mergeDates(availableDates, normalized);
    if (cached != null) {
      _updateState(
        _state.copyWith(
          status: RefereeAssignmentsStatus.ready,
          day: cached,
          isRefreshing: false,
          selectedDate: normalized,
          availableDates: combinedDates,
          error: null,
        ),
      );
    } else {
      _updateState(
        _state.copyWith(
          status: RefereeAssignmentsStatus.loading,
          day: null,
          isRefreshing: false,
          selectedDate: normalized,
          availableDates: combinedDates,
          error: null,
        ),
      );
    }
  }

  Future<void> _refreshSelected() async {
    if (_isFetching) return;
    _isFetching = true;
    final selectedDate = _selectedDate;
    final hasData = _state.day != null;
    _updateState(
      _state.copyWith(
        status: hasData
            ? RefereeAssignmentsStatus.ready
            : RefereeAssignmentsStatus.loading,
        isRefreshing: true,
        error: null,
        selectedDate: selectedDate,
      ),
    );
    try {
      final day = await _repository.fetchAndCache(date: selectedDate);
      final availableDates = await _repository.listCachedDates();
      _updateState(
        RefereeAssignmentsState(
          status: RefereeAssignmentsStatus.ready,
          day: day,
          isRefreshing: false,
          availableDates: _mergeDates(availableDates, selectedDate),
          selectedDate: selectedDate,
        ),
      );
    } catch (e) {
      final availableDates = await _repository.listCachedDates();
      _updateState(
        _state.copyWith(
          status: hasData
              ? RefereeAssignmentsStatus.ready
              : RefereeAssignmentsStatus.error,
          isRefreshing: false,
          error: e,
          availableDates: _mergeDates(availableDates, selectedDate),
          keepError: true,
        ),
      );
    } finally {
      _isFetching = false;
    }
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<DateTime> _mergeDates(List<DateTime> dates, DateTime include) {
    final set = <String, DateTime>{
      for (final date in dates) _normalizeDate(date).toIso8601String():
          _normalizeDate(date),
    };
    final normalizedInclude = _normalizeDate(include);
    set[normalizedInclude.toIso8601String()] = normalizedInclude;
    final sorted = set.values.toList()
      ..sort((a, b) => b.compareTo(a));
    return List.unmodifiable(sorted);
  }
}
