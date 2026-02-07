import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'repository.dart';

const String refereeAssignmentsTaskId = 'refereeAssignmentsDaily';
const String refereeAssignmentsTaskName = 'referee_assignments_fetch_task';

class RefereeAssignmentsBackgroundService {
  RefereeAssignmentsBackgroundService._();

  static final RefereeAssignmentsBackgroundService instance =
      RefereeAssignmentsBackgroundService._();

  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (!isSupported) return;
    if (_initialized) return;
    tz.initializeTimeZones();
    await Workmanager().initialize(
      refereeAssignmentCallbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    _initialized = true;
  }

  Future<void> scheduleDailyFetch() async {
    if (!isSupported) return;
    await ensureInitialized();
    final initialDelay = _computeInitialDelay();
    await Workmanager().registerPeriodicTask(
      refereeAssignmentsTaskId,
      refereeAssignmentsTaskName,
      frequency: const Duration(hours: 24),
      initialDelay: initialDelay,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 30),
    );
  }

  Duration _computeInitialDelay() {
    try {
      final location = tz.getLocation('America/New_York');
      final nowEastern = tz.TZDateTime.now(location);
      var target = tz.TZDateTime(
        location,
        nowEastern.year,
        nowEastern.month,
        nowEastern.day,
        9,
        5,
      );
      if (!target.isAfter(nowEastern)) {
        target = target.add(const Duration(days: 1));
      }
      final nowUtc = DateTime.now().toUtc();
      final targetUtc = target.toUtc();
      final diff = targetUtc.difference(nowUtc);
      if (diff.isNegative) {
        return const Duration(minutes: 1);
      }
      return diff;
    } catch (e) {
      debugPrint('Failed to compute initial delay: $e');
      return const Duration(hours: 1);
    }
  }

  bool get isSupported => !kIsWeb && Platform.isAndroid;
}

@pragma('vm:entry-point')
void refereeAssignmentCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      ui.DartPluginRegistrant.ensureInitialized();
    } catch (_) {
      // ignore
    }
    try {
      tz.initializeTimeZones();
    } catch (_) {
      // ignore duplicate init.
    }
    final repository = RefereeAssignmentsRepository.instance;
    try {
      await repository.fetchAndCache();
      return true;
    } catch (e, stack) {
      debugPrint('Background fetch failed: $e\n$stack');
      return false;
    }
  });
}
