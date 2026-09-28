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
no network calls, no analytics/telemetry.

- UI: Flutter + Material 3, dark theme only (`lib/theme/app_theme.dart`).
  UI language German, code/comments/identifiers English.
- DB: Drift (SQLite) via `NativeDatabase.createInBackground`
  (`lib/database/app_database.dart`, tables in `lib/models/tables.dart`).
- Settings: `shared_preferences`. Charts: `fl_chart` (custom
  `SimpleLineChart` in `lib/widgets/`). Fonts: `google_fonts` (Orbitron headers).
- Native: `MethodChannel('com.example.flutter_fitness/rest_timer')` for
  OPPO/OnePlus Live Alert chip + foreground rest-timer service.

```
lib/
  main.dart            # init DB, migrate icons, onboarding gate, MainScreen + 3 tabs
  models/tables.dart   # ALL Drift Table definitions (single file)
  database/            # app_database.dart + app_database.g.dart (generated)
  screens/             # home, active_workout, workout_detail?, exercise_list,
                       # analyse, onboarding, settings/gym_management
  widgets/             # dialogs, cards, rest_timer_overlay, simple_line_chart, ...
  utils/               # constants, formatters, backup/export/import_service,
                       # exercise_assets, backup_service
  theme/app_theme.dart # single ThemeData source (colors, shapes, input/button themes)
```

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
`flutter-setup-declarative-routing` (`BottomNavigationBar`, no `go_router`),
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

flutter analyze                    # must be clean
dart format .                      # never skip; generated *.g.dart excluded by tooling
flutter test                       # widget/unit tests in test/
flutter build apk --release        # output: build/app/outputs/flutter-apk/

# Drift codegen — after ANY change to tables.dart / app_database.dart:
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch        # during active DB work
```

Pre-commit (mirrors `flutter_workmanager` AGENTS.md practice):

```bash
dart format --set-exit-if-changed . 2>&1 | head -20
flutter analyze
flutter test
```

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
  ONLY in `lib/database/app_database.dart`.
- NEVER hand-edit `*.g.dart` — regenerate with `build_runner` (same rule as
  `flutter_workmanager` AGENTS.md: codegen via tool, never by hand).
- Current `schemaVersion` is 3. Every schema change must bump it AND extend
  `MigrationStrategy.onUpgrade`. The current `onUpgrade` is destructive
  (drop + reseed) — acceptable only pre-release; for any real user data,
  switch to `drift_dev make-migrations` + `stepByStep` (see Context7 snippet)
  instead of dropping tables.
- Use `batch()` for seeds/bulk inserts; `Value(...)` for nullable companion
  fields; `references(..., onDelete: KeyAction.cascade/setNull)` as in
  `tables.dart` — preserve CASCADE vs SET NULL semantics.
- Open via `NativeDatabase.createInBackground(File(.../ul_fitness.sqlite))`.
  Lazy connection, `getApplicationDocumentsDirectory()` — do not change path
  without a migration.
- Enforce in the app layer what SQLite can't (spec §2): `exercise_id` in
  `workout_exercises` / `workout_template_exercises` must belong to the
  parent's `gym_id`. `is_system` gyms can be renamed, never deleted.

## Domain rules (from spec — do not "fix")

- e1RM (Epley): `weight * (1 + reps / 30)`, only `weight > 0 && reps > 0`.
  `is_warmup` excluded; `is_failure` INCLUDED (informational only).
- Volume: `reps * weight_kg`. Same warmup/failure rule.
- Ghost data: strictly per-studio, stepwise from last completed workout with
  that `exercise_id` (1st click → 1st set, …; past end → repeat last set).
  No cross-studio fallback; empty if never done in this studio.
- Templates store exercise list + `order_idx` ONLY — no default sets/reps/weight.
- PRs are all-time (studio filter only); dashboard respects studio + time filter.
- Dates: display `dd.MM.yyyy HH:mm` (`intl`, de locale), store ISO 8601 local.
  Weight `0.0` kg, e1RM 1 decimal, volume integer, RPE 1–10 int.
- Categories: `Brust, Rücken, Beine, Schulter, Arme, Core, Ganzkörper, Cardio,
  Unterarme, Sonstiges`. Kinds: `machine, free_weight, cable, bodyweight`.

## Git & PR conventions

- Feature branches (`feature/...`, `fix/...`), German UI strings welcome but
  branch/commit messages in English, conventional commits
  (`feat:`, `fix:`, `docs:`, `refactor:`).
- Keep diffs small; update `Flutter_Fitness_Spec_v3.md` when behavior changes.
  No direct pushes to `main` for agent work — open a PR.
- Definition of done: `dart format` clean, `flutter analyze` clean,
  `flutter test` green, Drift codegen re-run if tables changed.

## References

- Spec: `Flutter_Fitness_Spec_v3.md` · Human intro: `README.md`
- Effective Dart: https://dart.dev/effective-dart (+ /style, /documentation, /usage, /design)
- Flutter docs: https://docs.flutter.dev · API: https://api.flutter.dev
- Drift: https://drift.simonbinder.eu (setup, migrations, step_by_step, tests)
- `flutter_lints`: https://pub.dev/packages/flutter_lints
- AGENTS.md format: https://agents.md · Examples: `flutter/packages`, `flutter/devtools`, `flutter_workmanager` (see links above)
