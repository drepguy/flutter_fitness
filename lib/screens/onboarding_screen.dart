import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.fitness_center,
      title: 'Willkommen bei\nFlutter Fitness',
      body: 'Tracke dein Training — Übungen, Sätze, Gewichte und Fortschritte. Alles lokal auf deinem Gerät.',
      color: AppTheme.primary,
    ),
    _OnboardingPage(
      icon: Icons.play_circle_outline,
      title: 'Training starten',
      body: 'Wähle ein Studio und tippe, um ein Training zu starten. Füge Übungen hinzu und logge deine Sätze mit Wiederholungen und Gewicht.\n\nDie App füllt automatisch deine letzten Gewichte vorheriger Trainings.\n\nStudios und Übungen können in den Einstellungen bzw. im Übungen-Tab angepasst werden.',
      color: AppTheme.secondary,
    ),
    _OnboardingPage(
      icon: Icons.speed,
      title: 'RPE — Rate of Perceived\nExertion',
      body: 'Bewerte jeden Satz von 1 bis 10:\n\n1 = leichtes Warm-up\n5 = mittelschwer\n7 = schwer, noch 2-3 Wdh. möglich\n10 = maximales Set\n\nSätze mit RPE ≥ 7 werden für die Analyse verwendet.',
      color: AppTheme.gold,
    ),
    _OnboardingPage(
      icon: Icons.analytics_outlined,
      title: 'Begriffe erklärt',
      body: 'e1RM (estimated 1-Rep Max)\nGeschätztes 1-Wiederholungs-Maximum basierend auf Gewicht und Wdh. (Epley-Formel).\n\nPR (Personal Record)\nDein bisher bestes Ergebnis pro Übung.\n\nVolumen\nGesamtgewicht: Gewicht × Wdh. pro Satz, summiert über alle Sätze.\n\nWdh.\nWiederholungen — wie oft du das Gewicht gehoben hast.',
      color: AppTheme.primary,
    ),
    _OnboardingPage(
      icon: Icons.timer_outlined,
      title: 'Pausentimer',
      body: 'Tippe auf einen der Preset-Chips (30s / 60s / 90s / 120s) nach einem Satz.\n\nDer Timer läuft auch im Hintergrund (Android 16+ mit Statusleiste-Chip). Vibration signalisiert das Ende.\n\nAnpassbar in den Einstellungen.',
      color: AppTheme.success,
    ),
    _OnboardingPage(
      icon: Icons.check_circle_outline,
      title: 'Los geht\'s',
      body: 'Noch ein paar Tipps:\n\n• Löschungen sind 8 Sekunden rückgängig machbar\n• Teile dein Training als Text\n• Aktiviere Auto-Backup in den Einstellungen\n• Passe Pausen-Timer und Vibration an',
      color: AppTheme.secondary,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _complete,
                child: Text(
                  'Überspringen',
                  style: TextStyle(color: AppTheme.muted, fontSize: 14),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => _pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  _buildDots(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _currentPage == _pages.length - 1
                          ? _complete
                          : () {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'Los geht\'s'
                            : 'Weiter',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: color),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}
