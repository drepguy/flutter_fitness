import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column, Index;
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/import_service.dart';
import '../utils/export_service.dart';
import 'active_workout_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppDatabase db;

  const HomeScreen({super.key, required this.db});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Gym> _gyms = [];
  List<Workout> _recentWorkouts = [];

  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _showImportDialog() async {
    final textController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Training importieren'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: TextField(
            controller: textController,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              hintText: 'Trainingsdaten hier einfügen...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importieren'),
          ),
        ],
      ),
    );

    if (confirmed == true && textController.text.isNotEmpty) {
      try {
        final service = ImportService(widget.db);
        await service.importNoteData(textController.text);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import erfolgreich!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }
  }

  Future<void> _exportAndShare() async {
    final service = ExportService(widget.db);
    final text = await service.exportAsText();
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'Flutter Fitness Export'),
    );
  }

  Future<void> _loadData() async {
    final gyms = await widget.db.select(widget.db.gyms).get();
    final workouts = await (widget.db.select(widget.db.workouts)
          ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
          ..limit(20))
        .get();

    setState(() {
      _gyms = gyms;
      _recentWorkouts = workouts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedIds.length} ausgewählt')
            : Text('Flutter Fitness',
                style: GoogleFonts.orbitron(
                    fontWeight: FontWeight.bold, fontSize: 20)),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selectionMode = false;
                  _selectedIds.clear();
                }),
              )
            : null,
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Alle auswählen',
              onPressed: () {
                setState(() {
                  if (_selectedIds.length == _recentWorkouts.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(
                        _recentWorkouts.map((w) => w.id));
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete,
                  color: AppTheme.error),
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () => _deleteSelectedWorkouts(),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: () => _showImportDialog(),
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _exportAndShare(),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(db: widget.db),
                  ),
                );
                _loadData();
              },
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            for (final gym in _gyms) _buildGymCard(gym),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('Letzte Trainings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
            ),
            const SizedBox(height: 8),
            if (_recentWorkouts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('Noch keine Trainings',
                        style: TextStyle(color: AppTheme.muted)),
                  ),
                ),
              )
            else
              for (final w in _recentWorkouts) _buildWorkoutCard(w),
          ],
        ),
      ),
    );
  }

  Widget _buildGymCard(Gym gym) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveWorkoutScreen(db: widget.db, gym: gym),
            ),
          );
          _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_arrow, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gym.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    if (gym.city != null)
                      Text(gym.city!,
                          style: const TextStyle(
                              color: AppTheme.muted, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(Workout workout) {
    final isActive = workout.endedAt == null;
    final isSelected = _selectedIds.contains(workout.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: () {
          if (!_selectionMode) {
            setState(() {
              _selectionMode = true;
              _selectedIds.add(workout.id);
            });
          }
        },
        onTap: () async {
          if (_selectionMode) {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(workout.id);
                if (_selectedIds.isEmpty) _selectionMode = false;
              } else {
                _selectedIds.add(workout.id);
              }
            });
            return;
          }
          final gym = await (widget.db.select(widget.db.gyms)
                ..where((g) => g.id.equals(workout.gymId!)))
              .getSingle();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveWorkoutScreen(
                db: widget.db,
                gym: gym,
                workout: workout,
              ),
            ),
          );
          _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected ? AppTheme.primary : AppTheme.muted,
                        size: 22,
                      ),
                    ),
                  Expanded(
                    child: FutureBuilder<Gym?>(
                      future: workout.gymId != null
                          ? (widget.db.select(widget.db.gyms)
                                ..where((g) => g.id.equals(workout.gymId!)))
                              .getSingleOrNull()
                          : Future.value(null),
                      builder: (context, snap) {
                        return Text(
                          snap.data?.name ?? 'Kein Studio',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.secondary.withValues(alpha: 0.2)
                          : AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isActive ? 'Aktiv' : 'Fertig',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isActive ? AppTheme.secondary : AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(formatDateTime(workout.startedAt),
                      style: const TextStyle(
                          color: AppTheme.muted, fontSize: 13)),
                  if (!isActive && workout.endedAt != null) ...[
                    const Text(' · ', style: TextStyle(color: AppTheme.muted)),
                    Text(
                        formatDuration(
                            workout.endedAt!.difference(workout.startedAt)),
                        style: const TextStyle(
                            color: AppTheme.muted, fontSize: 13)),
                  ],
                ],
              ),
              if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(workout.notes!,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSelectedWorkouts() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$count ${count == 1 ? 'Training' : 'Trainings'} löschen?'),
        content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
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
      await (widget.db.delete(widget.db.workouts)
            ..where((w) => w.id.isIn(_selectedIds)))
          .go();
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
      _loadData();
    }
  }
}
