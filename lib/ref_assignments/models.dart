import 'dart:convert';

enum OfficialRole { crewChief, referee, umpire, alternate }

String officialRoleLabel(OfficialRole role) {
  switch (role) {
    case OfficialRole.crewChief:
      return 'Crew Chief';
    case OfficialRole.referee:
      return 'Referee';
    case OfficialRole.umpire:
      return 'Umpire';
    case OfficialRole.alternate:
      return 'Alternate';
  }
}

OfficialRole officialRoleFromHeader(String header) {
  final normalized = header.trim().toLowerCase();
  if (normalized.contains('crew')) return OfficialRole.crewChief;
  if (normalized.contains('alternate')) return OfficialRole.alternate;
  if (normalized.contains('umpire')) return OfficialRole.umpire;
  return OfficialRole.referee;
}

class RefereeOfficial {
  const RefereeOfficial({
    required this.role,
    required this.name,
    this.number,
  });

  final OfficialRole role;
  final String name;
  final int? number;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'role': role.name,
        'name': name,
        if (number != null) 'number': number,
      };

  factory RefereeOfficial.fromJson(Map<String, dynamic> json) {
    return RefereeOfficial(
      role: OfficialRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => OfficialRole.referee,
      ),
      name: json['name'] as String? ?? '',
      number: json['number'] as int?,
    );
  }
}

class RefereeGameAssignment {
  const RefereeGameAssignment({
    required this.rawMatchup,
    required this.visitorTeam,
    required this.homeTeam,
    required this.officials,
  });

  final String rawMatchup;
  final String visitorTeam;
  final String homeTeam;
  final List<RefereeOfficial> officials;

  String get displayMatchup => visitorTeam.isNotEmpty && homeTeam.isNotEmpty
      ? '$visitorTeam @ $homeTeam'
      : rawMatchup;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rawMatchup': rawMatchup,
        'visitorTeam': visitorTeam,
        'homeTeam': homeTeam,
        'officials': officials.map((e) => e.toJson()).toList(),
      };

  factory RefereeGameAssignment.fromJson(Map<String, dynamic> json) {
    final officialMaps = (json['officials'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>();
    return RefereeGameAssignment(
      rawMatchup: json['rawMatchup'] as String? ?? '',
      visitorTeam: json['visitorTeam'] as String? ?? '',
      homeTeam: json['homeTeam'] as String? ?? '',
      officials:
          officialMaps.map((map) => RefereeOfficial.fromJson(map)).toList(),
    );
  }
}

class RefereeAssignmentsDay {
  const RefereeAssignmentsDay({
    required this.date,
    required this.fetchedAt,
    required this.games,
    required this.replayCenterCrew,
  });

  final DateTime date;
  final DateTime fetchedAt;
  final List<RefereeGameAssignment> games;
  final List<String> replayCenterCrew;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date.toIso8601String(),
        'fetchedAt': fetchedAt.toIso8601String(),
        'games': games.map((game) => game.toJson()).toList(),
        'replayCenterCrew': replayCenterCrew,
      };

  factory RefereeAssignmentsDay.fromJson(Map<String, dynamic> json) {
    final gameMaps = (json['games'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>();
    return RefereeAssignmentsDay(
      date: DateTime.parse(json['date'] as String),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      games: gameMaps.map(RefereeGameAssignment.fromJson).toList(),
      replayCenterCrew:
          (json['replayCenterCrew'] as List<dynamic>? ?? []).cast<String>(),
    );
  }

  String toPrettyJson() =>
      const JsonEncoder.withIndent('  ').convert(toJson());
}
