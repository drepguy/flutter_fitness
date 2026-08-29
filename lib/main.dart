import 'package:flutter/material.dart';
import 'database/app_database.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/exercise_list_screen.dart';
import 'screens/analyse_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  runApp(MyApp(db: db));
}

class MyApp extends StatelessWidget {
  final AppDatabase db;

  const MyApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Fitness',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/home': (_) => MainScreen(db: db),
      },
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

  late final List<Widget> _screens = [
    HomeScreen(db: widget.db),
    ExerciseListScreen(db: widget.db),
    AnalyseScreen(db: widget.db),
  ];

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
