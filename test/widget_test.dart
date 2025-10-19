import 'package:flutter_test/flutter_test.dart';

import 'package:referee_assignments_app/main.dart';

void main() {
  testWidgets('renders assignments screen title', (tester) async {
    await tester.pumpWidget(const RefereeAssignmentsApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('NBA Referee Assignments'), findsOneWidget);
  });
}
