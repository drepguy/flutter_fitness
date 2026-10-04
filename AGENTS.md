# AGENTS.md — Flutter Fitness

> Agent guide for this repo. Source of truth for product behavior is
> `Flutter_Fitness_Spec_v3.md` (+ `README.md`). This file is about
> *how to work* in the codebase: commands, Dart/Flutter conventions,
> and project-specific gotchas.
>
> Conventions below follow [Effective Dart](https://dart.dev/effective-dart)
> (Style / Documentation / Usage / Design),
> [Flutter docs](https://docs.flutter.dev) (`/flutter/website` on Context7),
> [Drift docs](https://drift.simonbinder.eu) (`/websites/drift_simonbinder_eu`),
> and the `AGENTS.md` pattern used by
> [`flutter/packages`](https://github.com/flutter/packages/blob/main/AGENTS.md)
> and [`fluttercommunity/flutter_workmanager`](https://github.com/fluttercommunity/flutter_workmanager/blob/main/AGENTS.md):
> format everything, keep `analyze` + tests green, never hand-edit generated code.

## Project overview

Local-first, privacy-focused fitness tracker (Android). No server, no auth,
no analytics/telemetry.

- UI: Flutter + Material 3, dark theme only (`lib/theme/app_theme.dart`).
  UI language German, code/comments/identifiers English. No
  `flutter_localizations` / ARB files — all UI strings are hardcoded German.
- DB: Drift (SQLite) via `NativeDatabase.createInBackground`
  (`lib/database/app_database.dart`, tables in `lib/models/tables.dart`).
- Settings: `shared_preferences` only (onboarding, rest presets, vibration,
  backup flags, icon-migration flag) — no settings service/layer.
- Charts: **custom `SimpleLineChart`** (`lib/widgets/simple_line_chart.dart`,
  hand-rolled `CustomPainter`). `fl_chart` sits in `pubspec.yaml` but is
  **never imported in `lib/`** — don't assume it's available in code.
- Fonts: `google_fonts` (`GoogleFonts.orbitron` in `theme/app_theme.dart` and
  `onboarding_screen.dart`). No `fonts:` section in `pubspec.yaml` and no
  bundled `.ttf` → google_fonts fetches at runtime; the release manifest
  declares no `INTERNET` permission, so offline builds fall back to the
  default font. Bundling Orbitron would be the fix if ever needed.
- Native: `MethodChannel('com.example.flutter_fitness/rest_timer')` for
  OPPO/OnePlus/Realme Live Alert chip (Android 16 / SDK 36+) + foreground
  rest-timer service — see "Native Android" below.

```
lib/
  main.dart            # init DB, auto-backup, icon migration, onboarding gate,
                       # MainScreen + NavigationBar (3 tabs)
  models/tables.dart   # ALL 8 Drift Table definitions (single file)
  database/            # app_database.dart (seed + migration) + app_database.g.dart
  screens/             # home, active_workout (largest, ~1350 lines), exercise_list,
                       # analyse, onboarding, settings (incl. gym management)
  widgets/             # dialogs, cards, simple_line_chart, rest_timer_overlay (dead)
  utils/               # constants, formatters, exercise_assets,
                       # backup/export/import_service
  theme/app_theme.dart # single ThemeData source (colors, shapes, input/button themes)
```

Rough sizes: `active_workout_screen` ~44 KB, `analyse` ~21 KB,
`settings` ~18 KB, `home` ~18 KB — everything else ≤ 10 KB.

## Navigation & screens

No named routes, no `go_router` — plain
`Navigator.push(MaterialPageRoute(...))` plus a `NavigationBar` in `MainScreen`
(`lib/main.dart`):

- **Tabs:** Training → `HomeScreen`, Übungen → `ExerciseListScreen`,
  Analyse → `AnalyseScreen`.
- **Starting a workout:** tap a gym card on Home → `ActiveWorkoutScreen(db,
  gym)` which *immediately inserts a new `Workouts` row* and starts a
  stopwatch. Tapping a workout card reopens the same screen with `workout:`
  (resume a paused workout, or view/edit a finished one).
- **Settings** (only entry: gear icon on Home) also hosts **gym management**
  ("Studios" section + `widgets/gym_edit_dialog.dart`), rest-timer presets,
  vibration and backup controls. Spec §4.7 "Studios Verwalten Screen" is
  implemented *inside* Settings, not as a separate screen.
- **No `workout_detail` screen** (spec §4.4 unimplemented): finished workouts
  reopen `ActiveWorkoutScreen`, where "Teilen" (share text) and
  "Zeiten bearbeiten" are offered when `endedAt != null`.
- **Templates are DB-only:** `workout_templates` /
  `workout_template_exercises` exist in schema + export/import, but no
  screen/dialog references them yet.
- On first run: `OnboardingScreen` (6 pages) gates `MainScreen` via pref
  `onboarding_done`.

## Agent skills — installed in `.agents/skills/`

Official skills from [`flutter/agent-plugins`](https://github.com/flutter/agent-plugins)
+ [`dart-lang/skills`](https://github.com/dart-lang/skills), installed via:

```bash
npx skills add flutter/agent-plugins --skill '*' --agent universal --yes
npx skills add dart-lang/skills --skill '*' --agent universal --yes
npx skills update   # refresh later
```

Load with the `skill` tool when the task matches. Highest value here:
`flutter-add-widget-test`, `dart-add-unit-test`, `dart-run-static-analysis`,
`flutter-fix-layout-issues`, `flutter-build-responsive-layout`.

Removed as 100% inapplicable (verified: no usage, no dependency, spec
contradicts): `flutter-use-http-package` (local-only, spec §15),
`flutter-setup-localization` (German-hardcoded, no `flutter_localizations`),
`flutter-setup-declarative-routing` (`NavigationBar`, no `go_router`),
`dart-setup-ffi-assets` / `dart-use-ffigen` (no `hook/`, no `ffigen`),
`dart-build-cli-app` (Flutter app, not a CLI).
Kept on purpose (borderline, not 100%): `flutter-implement-json-serialization`
(backup export/import in `lib/utils/` uses JSON), coverage/mocks/checks/path/
pattern-matching/primary-constructors/doc-examples, `flutter-add-integration-test`,
`flutter-add-widget-preview`, `flutter-apply-architecture-best-practices`,
`dart-resolve-package-conflicts`, `dart-fix-runtime-errors`,
`dart-write-documentation`.

## Setup & common commands

```bash
flutter pub get
flutter run                       # Android 10+ device/emulator

flutter analyze                    # must be clean for YOUR changes
dart format .                      # never skip; generated *.g.dart excluded by tooling
flutter test                       # test/ (currently one stub — see below)
flutter build apk --release        # output: build/app/outputs/flutter-apk/

# Drift codegen — after ANY change to tables.dart / app_database.dart:
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch        # during active DB work
```

Pre-commit (PowerShell-friendly; mirrors `flutter_workmanager` practice):

```powershell
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Verified baseline (2026-10):

- `flutter test` passes — but `test/widget_test.dart` is an empty
  `// TODO: Add app tests` stub; there is **no real coverage yet**. Add tests
  when touching logic (`dart-add-unit-test` / `flutter-add-widget-test`).
- `flutter analyze` currently reports ~25 pre-existing issues (5 warnings:
  unused field/local in `active_workout_screen.dart`, unused imports in
  `exercise_assets.dart` + `icon_picker_dialog.dart`; rest are infos like
  `use_build_context_synchronously`, `unnecessary_underscores`,
  `unnecessary_brace_in_string_interps`). Don't add new ones; clean up the
  warnings when you touch those files.
- Default branch is **`master`** (not `main`).

## Context7 — use it for library docs

`npx ctx7@latest` works here without setup. Always `library` first, then `docs`
(one topic per query). Verified IDs for this repo:

| Package | Context7 ID | Use for |
|---|---|---|
| Drift | `/websites/drift_simonbinder_eu` | migrations, `MigrationStrategy`, `stepByStep`, batch, streams |
| fl_chart | `/websites/pub_dev_fl_chart` | Bar/LineChart config, touch, 0.x breaking changes |
| Flutter framework | `/flutter/website`, `/websites/flutter_dev`, `/websites/api_flutter_dev` | widgets, M3, perf, API signatures |
| share_plus | `/websites/pub_dev_packages_share_plus` | `SharePlus.instance.share()` (static API is gone) |

```bash
npx ctx7@latest library "drift" "database migration setup"
npx ctx7@latest docs /websites/drift_simonbinder_eu "step-by-step schema migration"
npx ctx7@latest docs /flutter/website "StatefulWidget vs StatelessWidget best practices"
```

Do not rely on training data for Drift / `share_plus` / `file_picker` / Flutter
API signatures — they break often. Fetch current docs.

## Dart — Effective Dart + flutter_lints (required)

`analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`.
Follow https://dart.dev/effective-dart and https://dart.dev/tools/analysis:

- `dart format`; prefer ≤80 cols; curly braces for all flow control.
- Naming: `UpperCamelCase` types/extensions, `lowercase_with_underscores`
  files/packages, `lowerCamelCase` members, `lowercase_with_underscores` import prefixes.
- Imports: `dart:` → `package:` → relative, alphabetically sorted. No `../`
  escaping `lib/` from tests — use `package:flutter_fitness/...`.
- Prefer `async`/`await` over raw futures; no `async` without `await`;
  use `rethrow`, don't swallow catches; don't explicitly catch `Error`.
- Prefer expression bodies (`=>`) for trivial members; prefer `final`/`const`
  where possible; avoid `print` in app code (`avoid_print` lint).
- `///` doc comments on all public members — explain *why*, not *what*.
  Keep comments non-redundant (per `flutter/packages` AGENTS.md rule).
- No `// ignore:` without a justification comment; never broaden
  `analysis_options.yaml` excludes to silence a new warning.

## Flutter best practices (from Flutter docs)

- `StatelessWidget` for immutable UI, `StatefulWidget` only when the widget
  itself owns aesthetic/local state. User data / shared state belongs in the
  parent or a service, lifted out of the widget.
- `const` constructors everywhere possible; pass `super.key`; split large
  `build()` methods into small private widgets to limit rebuild scope.
- Never call `setState` in animation listeners per-frame — use
  `AnimatedBuilder` / `AnimatedWidget` / `PositionedTransition` so only the
  animated subtree rebuilds.
- Material 3 only (`useMaterial3: true`). No hardcoded colors/text styles —
  use `AppTheme.*` constants and `Theme.of(context)`. Cards `radius 14–16`,
  buttons `radius 12`, bottom bars `surfaceContainerHigh` + elevation 8
  (per spec §13).
- Layout: `LayoutBuilder`/`Expanded`/`Flexible` for responsiveness; fix
  `RenderFlex overflowed` / unbounded-height errors with constraints, not
  magic numbers. No raw strings/numbers in UI code — named constants in
  `utils/constants.dart` or `AppTheme`.
- Dispose `TextEditingController`, `AnimationController`, `Timer`,
  `StreamSubscription` in `dispose()`. Guard async gaps with
  `if (!mounted || !context.mounted) return;` (see `main.dart::_checkLiveInfo`).
- Null safety is non-negotiable: no `!` without a preceding null check or
  proof of invariance.

## Drift / database rules (strict)

- Tables live ONLY in `lib/models/tables.dart`. DB class + seed + migration
  ONLY in `lib/database/app_database.dart`. Queries live inline in screens —
  `lib/database/daos/` exists but is **empty**; don't invent a DAO layer
  without discussion.
- NEVER hand-edit `*.g.dart` — regenerate with `build_runner` (same rule as
  `flutter_workmanager` AGENTS.md: codegen via tool, never by hand).
- Current `schemaVersion` is 3. Every schema change must bump it AND extend
  `MigrationStrategy.onUpgrade`. The current `onUpgrade` is destructive
  (drop all tables + recreate + reseed) — acceptable only pre-release; for any
  real user data, switch to `drift_dev make-migrations` + `stepByStep` (see
  Context7 snippet) instead of dropping tables.
- `_seedData()` creates 2 gyms ("Thomas Sport Center", "All Inclusive
  Fitness") + 28 exercises with aliases — German names, uses `batch()` for
  gyms; run on `onCreate` AND after every destructive `onUpgrade`.
- Use `batch()` for seeds/bulk inserts; `Value(...)` for nullable companion
  fields; `references(..., onDelete: KeyAction.cascade/setNull)` as in
  `tables.dart` — preserve CASCADE vs SET NULL semantics.
- Open via `NativeDatabase.createInBackground(File(.../ul_fitness.sqlite))`.
  Lazy connection, `getApplicationDocumentsDirectory()` — do not change path
  without a migration.
- Enforce in the app layer what SQLite can't (spec §2): `exercise_id` in
  `workout_exercises` / `workout_template_exercises` must belong to the
  parent's `gym_id`. `is_system` gyms can be renamed, never deleted.

## Native Android (`android/app/src/main/kotlin/.../flutter_fitness/`)

Channel `com.example.flutter_fitness/rest_timer`:

| Direction | Method | Behavior |
|---|---|---|
| Dart→native | `isSupported` | `Build.VERSION.SDK_INT >= 36` (Android 16) |
| Dart→native | `startTimer {duration}` | starts `RestTimerService`, returns endTime |
| Dart→native | `stopTimer` | stops the service |
| Dart→native | `requestNotificationPermission` | `POST_NOTIFICATIONS` (+ promoted on SDK 36) |
| Dart→native | `checkLiveInfoStatus` | drives the "Live Info aktivieren" hint dialog in `MainScreen._checkLiveInfo` |
| Dart→native | `openNotificationSettings` | opens app notification settings |
| native→Dart | `onTimerCompleted` | broadcast → stops ticker + vibrates in Dart |

- `RestTimerService.kt`: foreground service (`specialUse`), low-importance
  countdown notification; on SDK ≥ 36 sets the promoted-ongoing flag so
  OPPO/OnePlus show the status-bar chip; vibrates natively on completion.
- On SDK < 36 there is **no native path** — `ActiveWorkoutScreen` falls back
  to an in-app `AnimationController` ticker (no background countdown).
- Manifest: `MANAGE_EXTERNAL_STORAGE`, `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`,
  `POST_PROMOTED_NOTIFICATIONS`; Impeller explicitly enabled
  (`io.flutter.embedding.android.EnableImpeller = true`).
- Note: completion can trigger **both** the native vibration and Dart's
  `_vibrate()` (prefs `vib_duration/vib_count/vib_gap`) → double buzz on
  supported devices. Don't "fix" one side without checking the other.

## Data, backup & assets gotchas

- `BackupService` writes to hardcoded `/storage/emulated/0/Documents/Flutter_Fitness`
  (`backup_yyyy-MM-dd_HH-mm.json`). `autoBackupIfNeeded()` runs at every app
  start, once per day, **default enabled** (pref `auto_backup_enabled`).
  Restore is merge-only.
- Export: `export_service.dart` → `{version: 1, exportedAt, gyms, exercises,
  exerciseAliases, workouts, workoutExercises, workoutSets, workoutTemplates,
  workoutTemplateExercises}`; file `flutter_fitness_export.json` in temp dir.
- Import: `import_service.dart` merges by natural keys (gyms by lowercased
  name; exercises by name — existing rows get `iconKey`/`category`/`kind`
  overwritten; workouts by `startedAt+gymId`; sets by `weId+setNo`; …),
  throws a German error for unknown `version`. Home app bar drives
  import/export/share (`file_picker`, `share_plus`).
- Exercise images: 610 files in `assets/exercises/` (`*.webp` +
  `exercises_meta.json`), declared in `pubspec.yaml`. `tools/download_all.ps1`
  / `download_exercises.ps1` fetch from `exercise-dataset.com` and regenerate
  the meta file — scripts contain **hardcoded absolute `D:\git\...` paths**.
- `utils/exercise_assets.dart` resolves images: exact name → alias →
  substring (`getExerciseImage`), `getIconAsset(iconKey)` falls back to the
  literal key path; `getAllIconOptions()` parses+caches `exercises_meta.json`.
  One-time icon migration (`dumbbell` → heuristics) runs in `main()` gated by
  pref `exercise_icons_migrated`.

## Domain rules (from spec — do not "fix")

- e1RM (Epley): `weight * (1 + reps / 30)`, only `weight > 0 && reps > 0`
  (`estimateOneRepMax` in `utils/constants.dart`).
  `is_warmup` excluded; `is_failure` INCLUDED (informational only).
- Volume: `reps * weight_kg` (`calculateVolume`). Same warmup/failure rule.
- Analyse filters (hardcoded in `analyse_screen.dart` — easy to miss):
  chart series and PR queries use `!isWarmup && rpe >= 7` (+ PRs also require
  `workouts.endedAt != null` and the studio filter); dashboard stats and
  monthly volume use `!isWarmup` only (no RPE filter). Time chips are
  28/84/180/365/730/1095 days (default 365); gym filter default "Alle Studios".
- Ghost data: strictly per-studio, stepwise from the last completed workout
  in that gym **that contains the exercise** — independent of exercise order
  or training day split (1st click → 1st set, …; past end → repeat last set).
  No cross-studio fallback; empty if never done in this studio.
- Next-exercise suggestion ("Empfohlen", `_predictNextExercise`) is strictly
  per-studio: every candidate comes from finished workouts in the *current*
  gym only (exercise availability differs per gym). Empty session → opener of
  the 2nd-last workout (alternating days); otherwise **majority vote** over
  the immediate successors of the last-added exercise across history
  ("what usually comes next", ties → newest workout; walks back through
  today's exercises when one has no history yet), then day detection by
  exercise overlap (containment, ties → newer workout) — inside the matched
  workout continue after the anchor, else first not-yet-done — finally the
  next not-yet-done exercise of the most recent workout. Pure selection
  logic lives in `utils/suggestion_logic.dart`, unit-tested in `test/utils/`.
- Templates store exercise list + `order_idx` ONLY — no default sets/reps/weight.
- PRs are all-time within the studio filter (plus the `!warmup && rpe >= 7`
  and finished-workout conditions noted above); dashboard respects studio +
  time filter.
- Dates: display `dd.MM.yyyy HH:mm` (`intl`, de locale), store ISO 8601 local.
  Weight `0.0` kg, e1RM 1 decimal, volume integer (`k` suffix ≥ 1000 in
  `formatters.dart`), RPE 1–10 int.
- Categories: `Brust, Rücken, Beine, Schulter, Arme, Core, Ganzkörper, Cardio,
  Unterarme, Sonstiges`. Kinds: `machine, free_weight, cable, bodyweight`
  (German labels via `exerciseKindLabels`).

## Known gaps / dead code (verified — don't "discover" these as new)

- `lib/widgets/rest_timer_overlay.dart` is **never imported** — the live rest
  timer is inline in `ActiveWorkoutScreen`.
- `fl_chart` dependency unused in `lib/` (custom painter chart instead).
- No `workout_detail` screen, no template UI, no separate studios screen
  (spec §4.4 / templates / §4.7 partially unimplemented by design so far).
- `test/widget_test.dart` is an empty stub.
- Two vibration paths (Dart `vibration` + native service) — see Native Android.

## Git & PR conventions

- Feature branches (`feature/...`, `fix/...`), German UI strings welcome but
  branch/commit messages in English, conventional commits
  (`feat:`, `fix:`, `docs:`, `refactor:`). Default branch: `master`.
- Keep diffs small; update `Flutter_Fitness_Spec_v3.md` when behavior changes.
  No direct pushes to `master` for agent work — open a PR.
- Definition of done: `dart format` clean, `flutter analyze` adds no new
  issues, `flutter test` green, Drift codegen re-run if tables changed.

## References

- Spec: `Flutter_Fitness_Spec_v3.md` (~560 lines; §1 Architektur, §2 Schema,
  §3 Seeds, §4 Screens, §5 Berechnungen, §6 Kategorien, §7 Farbschema,
  §8 Navigation, §9 Ghost-Daten, §10 Features, §11 Datenformat, §12 Migration,
  §13 Technische Hinweise, §14 Screens-Zusammenfassung, §15 Nicht enthalten)
- Human intro: `README.md` (note: README's "30/90/365/1095 days" filter list
  is stale — actual chips are 28/84/180/365/730/1095)
- Effective Dart: https://dart.dev/effective-dart (+ /style, /documentation, /usage, /design)
- Flutter docs: https://docs.flutter.dev · API: https://api.flutter.dev
- Drift: https://drift.simonbinder.eu (setup, migrations, step_by_step, tests)
- `flutter_lints`: https://pub.dev/packages/flutter_lints
- AGENTS.md format: https://agents.md · Examples: `flutter/packages`, `flutter/devtools`, `flutter_workmanager` (see links above)
