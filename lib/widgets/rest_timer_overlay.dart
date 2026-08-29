import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../theme/app_theme.dart';

class RestTimerOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const RestTimerOverlay({super.key, required this.onClose});

  @override
  State<RestTimerOverlay> createState() => _RestTimerOverlayState();
}

class _RestTimerOverlayState extends State<RestTimerOverlay> {
  int _seconds = 90;
  bool _running = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '$_seconds');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    setState(() => _running = true);
    _tick();
  }

  void _tick() async {
    while (_running && _seconds > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!_running) return;
      setState(() => _seconds--);
    }
    if (_seconds <= 0) {
      _running = false;
      final prefs = await SharedPreferences.getInstance();
      final dur = prefs.getInt('vib_duration') ?? 500;
      final count = prefs.getInt('vib_count') ?? 4;
      final gap = prefs.getInt('vib_gap') ?? 600;
      for (int i = 0; i < count; i++) {
        Vibration.vibrate(duration: dur);
        if (i < count - 1) {
          await Future.delayed(Duration(milliseconds: gap));
        }
      }
      widget.onClose();
    }
  }

  void _pause() {
    setState(() => _running = false);
  }

  void _reset(int sec) {
    setState(() {
      _running = false;
      _seconds = sec;
      _controller.text = '$sec';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(_seconds),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_running)
                ElevatedButton(
                  onPressed: _start,
                  child: const Text('Start'),
                )
              else
                OutlinedButton(
                  onPressed: _pause,
                  child: const Text('Pause'),
                ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                children: [
                  ActionChip(
                    label: const Text('30s', style: TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _reset(30),
                  ),
                  ActionChip(
                    label: const Text('60s', style: TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _reset(60),
                  ),
                  ActionChip(
                    label: const Text('90s', style: TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _reset(90),
                  ),
                  ActionChip(
                    label: const Text('120s', style: TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _reset(120),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
