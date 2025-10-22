import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../widgets/official_avatar.dart';

class AssignmentDetailScreen extends StatefulWidget {
  const AssignmentDetailScreen({
    super.key,
    required this.assignment,
    required this.assignmentDate,
  });

  final RefereeGameAssignment assignment;
  final DateTime assignmentDate;

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignment = widget.assignment;
    final primaryOfficials = assignment.officials
        .where((official) => official.role != OfficialRole.alternate)
        .toList();
    final alternate = assignment.officials
        .where((official) => official.role == OfficialRole.alternate)
        .map((official) => official.name)
        .toList();
    final matchupLabel = assignment.displayMatchup.toUpperCase();
    final baseMatchupStyle = theme.textTheme.headlineMedium ??
        theme.textTheme.displaySmall ??
        theme.textTheme.titleLarge ??
        theme.textTheme.titleMedium;
    final matchupBaseSize = baseMatchupStyle?.fontSize ?? 32;
    final matchupStyle = (baseMatchupStyle ??
            const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ))
        .copyWith(
      fontWeight: FontWeight.bold,
      color: Colors.black,
      fontSize: matchupBaseSize * 1.3,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final cardWidth = availableWidth * 0.95;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: availableWidth < 600 ? availableWidth : cardWidth,
                ),
                child: AspectRatio(
                  aspectRatio: 11 / 8.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            matchupLabel,
                            style: matchupStyle,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          if (primaryOfficials.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                'Officials not posted.',
                                style: theme.textTheme.titleMedium,
                              ),
                            )
                          else
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 24,
                              runSpacing: 24,
                              children: primaryOfficials.map((official) {
                                return OfficialAvatar(
                                  official: official,
                                  size: 160,
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 12),
                          if (alternate.isNotEmpty)
                            Text(
                              'Alternate: ${alternate.join(', ')}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
