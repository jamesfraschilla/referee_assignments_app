class RefereeAssignmentsBackgroundService {
  RefereeAssignmentsBackgroundService._();

  static final RefereeAssignmentsBackgroundService instance =
      RefereeAssignmentsBackgroundService._();

  bool get isSupported => false;

  Future<void> ensureInitialized() async {}

  Future<void> scheduleDailyFetch() async {}
}
