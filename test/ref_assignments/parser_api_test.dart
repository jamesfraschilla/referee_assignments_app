import 'package:flutter_test/flutter_test.dart';

import 'package:referee_assignments_app/ref_assignments/models.dart';
import 'package:referee_assignments_app/ref_assignments/parser.dart';

void main() {
  group('RefereeAssignmentParser.parseFromApi', () {
    test('parses assignments and replay center crew from API payload', () {
      const apiResponse = {
        'nba': {
          'Table': {
            'rows': [
              {
                'game_date': '04/01/2024',
                'away_team': 'Boston',
                'home_team': 'Charlotte',
                'official1': 'Bill Kennedy',
                'official1_JNum': '55',
                'official2': 'Pat Fraher',
                'official2_JNum': '26',
                'official3': 'Brandon Schwab',
                'official3_JNum': '86',
                'official4': null,
                'official4_JNum': null,
              },
            ],
          },
          'Table1': {
            'rows': [
              {'replaycenter_official': 'James Williams'},
              {'replaycenter_official': 'Matt Myers'},
            ],
          },
        },
      };

      final parser = RefereeAssignmentParser();
      final fallbackDate = DateTime.utc(2024, 4, 1);
      final day = parser.parseFromApi(
        apiResponse,
        fallbackDate: fallbackDate,
      );

      expect(day.date.year, 2024);
      expect(day.date.month, 4);
      expect(day.date.day, 1);
      expect(day.games, hasLength(1));

      final game = day.games.single;
      expect(game.visitorTeam, 'Boston');
      expect(game.homeTeam, 'Charlotte');
      expect(game.officials, hasLength(3));

      final crewChief = game.officials.firstWhere(
        (official) => official.role == OfficialRole.crewChief,
      );
      expect(crewChief.name, 'Bill Kennedy');
      expect(crewChief.number, 55);

      final umpire = game.officials.firstWhere(
        (official) => official.role == OfficialRole.umpire,
      );
      expect(umpire.name, 'Brandon Schwab');

      expect(day.replayCenterCrew, ['James Williams', 'Matt Myers']);
    });
  });
}
