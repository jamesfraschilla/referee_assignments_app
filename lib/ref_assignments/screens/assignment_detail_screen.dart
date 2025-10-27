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
      DeviceOrientation.portraitUp,
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
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final assignment = widget.assignment;
    final primaryOfficials = assignment.officials
        .where((official) => official.role != OfficialRole.alternate)
        .toList();
    primaryOfficials.sort(
      (a, b) => _rolePriority(a.role).compareTo(_rolePriority(b.role)),
    );
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
      color: textColor,
      fontSize: matchupBaseSize * 1.3,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final orientation = MediaQuery.of(context).orientation;
            final isPortrait = orientation == Orientation.portrait;
            final availableWidth = constraints.maxWidth;
            final cardWidth = availableWidth * 0.95;
            final headerSpacing = isPortrait ? 18.0 : 12.0;
            final footerSpacing = isPortrait ? 4.0 : 12.0;

            final cardContent = DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          matchupLabel,
                          style: matchupStyle,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(height: headerSpacing),
                    if (primaryOfficials.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'Officials not posted.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: textColor,
                          ),
                        ),
                      )
                    else
                      _OfficialsLayout(
                        officials: primaryOfficials,
                        isPortrait: isPortrait,
                        textColor: textColor,
                      ),
                    SizedBox(height: footerSpacing),
                    if (alternate.isNotEmpty)
                      Text(
                        'Alternate: ${alternate.join(', ')}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                  ],
                ),
              ),
            );

            final displayCard = isPortrait
                ? AspectRatio(aspectRatio: 9 / 16, child: cardContent)
                : AspectRatio(aspectRatio: 11 / 8.5, child: cardContent);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: availableWidth < 600 ? availableWidth : cardWidth,
                  ),
                  child: displayCard,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OfficialsLayout extends StatelessWidget {
  const _OfficialsLayout({
    required this.officials,
    required this.isPortrait,
    required this.textColor,
  });

  final List<RefereeOfficial> officials;
  final bool isPortrait;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    if (isPortrait) {
      final width = MediaQuery.of(context).size.width;
      final portraitSize = width < 360 ? 120.0 : 130.0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: officials.map((official) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: OfficialAvatar(
              official: official,
              size: portraitSize,
              compact: true,
              textColor: textColor,
            ),
          );
        }).toList(),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 24,
      children: officials
          .map(
            (official) => OfficialAvatar(
              official: official,
              size: 160,
              compact: false,
              textColor: textColor,
            ),
          )
          .toList(),
    );
  }
}

int _rolePriority(OfficialRole role) {
  switch (role) {
    case OfficialRole.crewChief:
      return 0;
    case OfficialRole.referee:
      return 1;
    case OfficialRole.umpire:
      return 2;
    case OfficialRole.alternate:
      return 3;
  }
}
