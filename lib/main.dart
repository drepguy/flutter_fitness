import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column, Index;
import 'package:shared_preferences/shared_preferences.dart';
import 'database/app_database.dart';
import 'theme/app_theme.dart';
import 'utils/backup_service.dart';
import 'utils/constants.dart';
import 'screens/home_screen.dart';
import 'screens/exercise_list_screen.dart';
import 'screens/analyse_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  BackupService(db).autoBackupIfNeeded();
  await _migrateExerciseIcons(db);
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;
  runApp(MyApp(db: db, showOnboarding: !onboardingDone));
}

Future<void> _migrateExerciseIcons(AppDatabase db) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('exercise_icons_migrated') ?? false) return;

  final exercises = await db.select(db.exercises).get();
  for (final ex in exercises) {
    if (ex.iconKey == 'dumbbell') {
      final newIconKey = autoAssignIconKey(ex.name, ex.category);
      if (newIconKey != 'dumbbell') {
        await (db.update(db.exercises)..where((e) => e.id.equals(ex.id)))
            .write(ExercisesCompanion(iconKey: Value(newIconKey)));
      }
    }
  }
  await prefs.setBool('exercise_icons_migrated', true);
}

class MyApp extends StatefulWidget {
  final AppDatabase db;
  final bool showOnboarding;

  const MyApp({super.key, required this.db, required this.showOnboarding});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _showOnboarding = widget.showOnboarding;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Fitness',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: _showOnboarding
          ? OnboardingScreen(onComplete: () {
              setState(() => _showOnboarding = false);
            })
          : MainScreen(db: widget.db),
    );
  }
}

class MainScreen extends StatefulWidget {
  final AppDatabase db;

  const MainScreen({super.key, required this.db});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  static const _channel = MethodChannel('com.example.flutter_fitness/rest_timer');

  late final List<Widget> _screens = [
    HomeScreen(db: widget.db),
    ExerciseListScreen(db: widget.db),
    AnalyseScreen(db: widget.db),
  ];

  @override
  void initState() {
    super.initState();
    _checkLiveInfo();
  }

  Future<void> _checkLiveInfo() async {
    try {
      final result = await _channel.invokeMethod('checkLiveInfoStatus');
      if (result is Map) {
        final needsHint = result['needsHint'] == true;
        if (needsHint && mounted && context.mounted) {
          final prefs = await SharedPreferences.getInstance();
          final dismissed = prefs.getBool('live_info_hint_dismissed') ?? false;
          if (!dismissed) {
            if (!mounted || !context.mounted) return;
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1E1E2E),
                title: const Text('Live Info aktivieren'),
                content: const Text(
                  'Für den Status-Balken-Chip musst du "Live Info anzeigen" aktivieren:\n\n'
                  'Einstellungen → Apps → Flutter Fitness → Benachrichtigungen → Live Info anzeigen\n\n'
                  'Nach einem App-Neustart oder -Reinstall muss dies ggf. erneut aktiviert werden.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      _channel.invokeMethod('openNotificationSettings');
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Einstellungen öffnen'),
                  ),
                  TextButton(
                    onPressed: () {
                      prefs.setBool('live_info_hint_dismissed', true);
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Nicht mehr anzeigen'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Verstanden'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Training',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_outlined),
            selectedIcon: Icon(Icons.list),
            label: 'Übungen',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Analyse',
          ),
        ],
      ),
    );
  }
}
