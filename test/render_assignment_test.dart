import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:referee_assignments_app/ref_assignments/app_theme.dart';
import 'package:referee_assignments_app/ref_assignments/models.dart';
import 'package:referee_assignments_app/ref_assignments/screens/assignment_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Render assignment export image', (tester) async {
    final configPath = Platform.environment['RENDER_CONFIG'] ??
        const String.fromEnvironment('RENDER_CONFIG',
            defaultValue: 'build/render_config.json');
    final configFile = File(configPath);
    if (!configFile.existsSync()) {
      throw Exception('Missing render config at $configPath');
    }
    final config = jsonDecode(configFile.readAsStringSync())
        as Map<String, dynamic>;
    if (config['shouldSend'] != true) {
      return;
    }

    final assignment = RefereeGameAssignment.fromJson(
      (config['assignment'] as Map<String, dynamic>?) ?? {},
    );
    final assignmentDate =
        DateTime.parse(config['date'] as String? ?? DateTime.now().toString());
    final themeMode =
        (config['theme'] as String?) == 'dark' ? ThemeMode.dark : ThemeMode.light;
    final targetSize = _sizeFromList(config['targetSize']);
    final contentSize = _sizeFromList(config['contentSize']);
    final outputPath = config['outputPath'] as String? ?? 'build/assignment.png';

    final isLandscape = targetSize.width > targetSize.height;
    final testSize = isLandscape ? const Size(1600, 900) : const Size(900, 1600);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.window.physicalSizeTestValue =
        Size(testSize.width, testSize.height);

    final exportKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: themeMode,
        home: AssignmentDetailScreen(
          assignment: assignment,
          assignmentDate: assignmentDate,
          exportKey: exportKey,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final boundary = exportKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Failed to find render boundary.');
    }
    final image = await boundary.toImage(pixelRatio: 1.0);
    final backgroundColor = themeMode == ThemeMode.dark
        ? const Color.fromARGB(255, 0, 0, 0)
        : const Color.fromARGB(255, 255, 255, 255);

    final pngBytes = await renderAssignmentPngBytes(
      image,
      targetSize: targetSize,
      backgroundColor: backgroundColor,
      contentSize: contentSize,
    );
    image.dispose();
    if (pngBytes == null) {
      throw Exception('Failed to encode PNG.');
    }

    final outputFile = File(outputPath);
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsBytesSync(pngBytes);
  });
}

Size _sizeFromList(dynamic list) {
  if (list is List && list.length >= 2) {
    final width = (list[0] as num).toDouble();
    final height = (list[1] as num).toDouble();
    return Size(width, height);
  }
  return const Size(1536, 2592);
}
