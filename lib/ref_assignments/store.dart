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
    this.error,
  });

  final RefereeAssignmentsStatus status;
  final RefereeAssignmentsDay? day;
  final bool isRefreshing;
  final Object? error;

  RefereeAssignmentsState copyWith({
    RefereeAssignmentsStatus? status,
    RefereeAssignmentsDay? day,
    bool? isRefreshing,
    Object? error,
  }) {
    return RefereeAssignmentsState(
      status: status ?? this.status,
      day: day ?? this.day,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
    );
  }

  static RefereeAssignmentsState initial() => const RefereeAssignmentsState(
        status: RefereeAssignmentsStatus.idle,
        day: null,
        isRefreshing: false,
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

  Future<void> loadInitial() async {
    if (_state.status != RefereeAssignmentsStatus.idle) return;
    _updateState(
      _state.copyWith(status: RefereeAssignmentsStatus.loading),
    );
    final cached = await _repository.loadCachedDay();
    if (cached != null) {
      _updateState(
        _state.copyWith(
          status: RefereeAssignmentsStatus.ready,
          day: cached,
        ),
      );
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (_isFetching) return;
    _isFetching = true;
    final hasData = _state.day != null;
    _updateState(
      _state.copyWith(
        status: hasData
            ? RefereeAssignmentsStatus.ready
            : RefereeAssignmentsStatus.loading,
        isRefreshing: true,
        error: null,
      ),
    );
    try {
      final day = await _repository.fetchAndCache();
      _updateState(
        RefereeAssignmentsState(
          status: RefereeAssignmentsStatus.ready,
          day: day,
          isRefreshing: false,
        ),
      );
    } catch (e) {
      _updateState(
        _state.copyWith(
          status: hasData
              ? RefereeAssignmentsStatus.ready
              : RefereeAssignmentsStatus.error,
          isRefreshing: false,
          error: e,
        ),
      );
    } finally {
      _isFetching = false;
    }
  }

  void _updateState(RefereeAssignmentsState newState) {
    _state = newState;
    notifyListeners();
  }
}
