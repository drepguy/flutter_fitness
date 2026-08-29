import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../database/app_database.dart';
import '../theme/app_theme.dart';
import '../widgets/gym_edit_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final AppDatabase db;

  const SettingsScreen({super.key, required this.db});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Gym> _gyms = [];

  int _vibDuration = 500;
  int _vibCount = 4;
  int _vibGap = 600;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadVibrationSettings();
  }

  Future<void> _loadData() async {
    final gyms = await widget.db.select(widget.db.gyms).get();
    setState(() => _gyms = gyms);
  }

  Future<void> _loadVibrationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vibDuration = prefs.getInt('vib_duration') ?? 500;
      _vibCount = prefs.getInt('vib_count') ?? 4;
      _vibGap = prefs.getInt('vib_gap') ?? 600;
    });
  }

  Future<void> _saveVibrationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('vib_duration', _vibDuration);
    await prefs.setInt('vib_count', _vibCount);
    await prefs.setInt('vib_gap', _vibGap);
  }

  void _testVibration() async {
    for (int i = 0; i < _vibCount; i++) {
      Vibration.vibrate(duration: _vibDuration);
      if (i < _vibCount - 1) {
        await Future.delayed(Duration(milliseconds: _vibGap));
      }
    }
  }

  Future<void> _addGym() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => GymEditDialog(db: widget.db),
    );
    if (result != null) _loadData();
  }

  Future<void> _editGym(Gym gym) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => GymEditDialog(db: widget.db, gym: gym),
    );
    if (result != null) _loadData();
  }

  Future<void> _deleteGym(Gym gym) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Studio löschen?'),
        content: const Text(
            'Übungen und Trainings dieses Studios bleiben erhalten, verlieren aber die Studio-Zuordnung.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await (widget.db.delete(widget.db.gyms)
            ..where((g) => g.id.equals(gym.id)))
          .go();
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          _buildVibrationSection(),
          const Divider(height: 1),
          _buildGymSection(),
        ],
      ),
    );
  }

  Widget _buildVibrationSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.vibration, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Vibration',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'Dauer',
            value: _vibDuration,
            min: 100,
            max: 2000,
            step: 100,
            unit: 'ms',
            onChanged: (v) => setState(() => _vibDuration = v),
          ),
          _buildSlider(
            label: 'Anzahl',
            value: _vibCount,
            min: 1,
            max: 10,
            step: 1,
            unit: 'x',
            onChanged: (v) => setState(() => _vibCount = v),
          ),
          _buildSlider(
            label: 'Pause',
            value: _vibGap,
            min: 100,
            max: 2000,
            step: 100,
            unit: 'ms',
            onChanged: (v) => setState(() => _vibGap = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _testVibration,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Testen'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _vibDuration = 500;
                    _vibCount = 4;
                    _vibGap = 600;
                  });
                  _saveVibrationSettings();
                },
                child: const Text('Standard'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required int value,
    required int min,
    required int max,
    required int step,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: AppTheme.muted)),
          ),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: (max - min) ~/ step,
              label: '$value$unit',
              onChanged: (v) {
                onChanged(v.toInt());
                _saveVibrationSettings();
              },
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '$value$unit',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGymSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: const [
              Icon(Icons.fitness_center, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Studios',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _gyms.length,
          itemBuilder: (context, i) {
            final gym = _gyms[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(gym.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    if (gym.isSystem)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Standard',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.primary)),
                      ),
                  ],
                ),
                subtitle: gym.city != null
                    ? Text(gym.city!,
                        style: const TextStyle(
                            color: AppTheme.muted, fontSize: 13))
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _editGym(gym),
                    ),
                    if (!gym.isSystem)
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 20, color: AppTheme.error),
                        onPressed: () => _deleteGym(gym),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: OutlinedButton.icon(
            onPressed: _addGym,
            icon: const Icon(Icons.add),
            label: const Text('Neues Studio'),
          ),
        ),
      ],
    );
  }
}
