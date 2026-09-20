# Flutter Fitness

A local-first, privacy-focused fitness tracking app for Android — built with Flutter and native Android features.

Track your workouts, monitor your progress, and analyze your performance. Your data stays on your device.

## Features

### Workout Tracking
- Create and manage custom exercises with icons and categories
- Track sets, reps, weight, RPE, and failure markers
- Built-in rest timer with OPPO/OnePlus Live Alert countdown chip
- Add notes to workouts and individual exercises
- Workout history with detailed exercise breakdowns

### Exercise Library
- 600+ exercises with professional illustrations from [RepDB](https://repdb.co)
- Searchable icon picker with German and English exercise names
- Custom categories and exercise types (free weight, machine, cable, bodyweight, etc.)
- Exercise aliases for flexible search

### Analysis & Progress
- Volume, e1RM, and max weight charts over time
- Personal records tracking
- Filter by date range (30, 90, 365, 1095 days)
- Muscle group breakdown

### Data Management
- Automatic daily backups (optional)
- Manual backup/restore to local storage
- Full export/import as JSON
- Local-only — no account, no cloud, no tracking

### Onboarding
- Guided 6-card onboarding for new users
- Explains RPE, e1RM, volume, and other fitness concepts
- Rest timer setup and permission guidance

### UI/UX
- Material 3 dark theme
- Responsive layout
- Vibration feedback on set completion
- Google Fonts (Orbitron) for headers

## Screenshots

> Screenshots coming soon.

## Getting Started

### Prerequisites
- Flutter SDK 3.13.2+
- Android SDK 36+ (OPPO/OnePlus recommended for Live Alert chip)
- A physical device or emulator running Android 10+

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/drepguy/flutter_fitness.git
   cd flutter_fitness
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run on a connected device:
   ```bash
   flutter run
   ```

### Building

```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

## Tech Stack

- **Flutter** — cross-platform UI framework
- **Drift** — local SQLite database with type-safe queries
- **SharedPreferences** — lightweight settings storage
- **Vibration** — haptic feedback for set completion
- **Share Plus** — share workout summaries
- **Google Fonts** — Orbitron for display text

## Architecture

- **Database-first** — all data modeled in Drift tables, no REST API
- **Local-only** — no network calls, no analytics, no telemetry
- **Method Channel** — native Android integration for status bar countdown chip
- **Service layer** — background rest timer via Android foreground service

## Contributing

Contributions are welcome! Bug fixes, new features, and UI improvements are all appreciated.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

For questions or discussions, open an [issue](https://github.com/drepguy/flutter_fitness/issues).

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [RepDB](https://repdb.co) — exercise illustrations and metadata (CC BY-SA 4.0 for free tier assets)
- [Flutter](https://flutter.dev) — the UI framework
- [Drift](https://drift.simonbinder.eu) — the database layer
