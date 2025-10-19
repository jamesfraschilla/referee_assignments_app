# NBA Referee Assignments

Mobile companion that scrapes [official.nba.com/referee-assignments](https://official.nba.com/referee-assignments/) each morning, caches the crews, and presents a printable 11x8.5 matchup card with headshots.

## Highlights
- Automatic Android background refresh around 9:05 am Eastern via WorkManager
- Manual pull-to-refresh with last updated timestamp and error handling
- Printable detail sheet for each game with crew images, roles, and replay-center callouts
- Offline cache stored locally so the most recent data stays available without a network connection

## Setup

```bash
flutter pub get
flutter run
```

### Referee photo assets

Place your headshots inside `assets/referees/`. Files are resolved using a slugified version of the name:

```
Tony Brothers      -> assets/referees/tony_brothers.png
Sha'Rae Mitchell   -> assets/referees/sharae_mitchell.png
```

PNG is assumed by default; adjust `refereeAssetPath` in `lib/ref_assignments/photo_resolver.dart` if you prefer a different extension. The detail view falls back to initials if an asset cannot be loaded.

After adding images run `flutter pub get` again so Flutter picks up the asset directory changes.

### Background refresh notes

- Android is fully wired: initialization happens in `main()` and schedules a periodic WorkManager task aligned to the next 9:05 am ET window.
- iOS requires manual configuration (BGTaskScheduler identifiers, background-fetch entitlement, plist updates). The Dart side is ready, but no native configuration is included yet—data refreshes when the user opens the app or pulls to refresh.

### Manual checks

1. Launch the app and confirm cached data displays, then updates once the network call completes.
2. Pull-to-refresh to verify live fetching and caching.
3. Open a matchup and confirm the printable view renders correctly at 11x8.5 with your local images.
4. Toggle the theme icon to ensure the preference persists between launches.
