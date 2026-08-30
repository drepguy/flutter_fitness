import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column, Index;
import '../database/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/exercise_picker_dialog.dart';
import '../widgets/simple_line_chart.dart';
import '../widgets/pr_card.dart';
import '../widgets/stat_card.dart';

class AnalyseScreen extends StatefulWidget {
  final AppDatabase db;

  const AnalyseScreen({super.key, required this.db});

  @override
  State<AnalyseScreen> createState() => _AnalyseScreenState();
}

class _AnalyseScreenState extends State<AnalyseScreen> {
  List<Gym> _gyms = [];
  int? _selectedGymId;
  int _daysFilter = 9999;
  Exercise? _selectedExercise;
  String _metric = 'e1rm';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final gyms = await widget.db.select(widget.db.gyms).get();
    setState(() => _gyms = gyms);
  }

  DateTime get _fromDate => DateTime.now().subtract(Duration(days: _daysFilter));

  Future<List<Map<String, dynamic>>> _getExerciseData() async {
    if (_selectedExercise == null) return [];

    final workouts = await (widget.db.select(widget.db.workouts)
          ..where((w) =>
              w.endedAt.isNotNull() &
              w.startedAt.isBiggerOrEqualValue(_fromDate) &
              (_selectedGymId != null
                  ? w.gymId.equals(_selectedGymId!)
                  : const Constant(true)))
        ..orderBy([(w) => OrderingTerm.asc(w.startedAt)]))
        .get();

    final data = <Map<String, dynamic>>[];
    for (final w in workouts) {
      final we = await (widget.db.select(widget.db.workoutExercises)
            ..where((e) =>
                e.workoutId.equals(w.id) &
                e.exerciseId.equals(_selectedExercise!.id))
          ..limit(1))
          .getSingleOrNull();
      if (we == null) continue;

      final sets = await (widget.db.select(widget.db.workoutSets)
            ..where((s) =>
                s.workoutExerciseId.equals(we.id) & s.isWarmup.equals(false))
          ..orderBy([(s) => OrderingTerm.asc(s.setNo)]))
          .get();

      if (sets.isEmpty) continue;

      double maxWeight = 0;
      double bestE1rm = 0;
      double volume = 0;
      for (final s in sets) {
        if (s.weightKg > maxWeight) maxWeight = s.weightKg;
        final e1rm = estimateOneRepMax(s.weightKg, s.reps);
        if (e1rm > bestE1rm) bestE1rm = e1rm;
        volume += calculateVolume(s.reps, s.weightKg);
      }

      data.add({
        'date': w.startedAt,
        'e1rm': bestE1rm,
        'volume': volume,
        'maxWeight': maxWeight,
      });
    }
    return data;
  }

  Future<Map<String, dynamic>> _getPRs() async {
    if (_selectedExercise == null) {
      return {'maxWeight': 0, 'bestE1rm': 0, 'maxVolume': 0};
    }

    final query = widget.db.select(widget.db.workoutSets).join([
      innerJoin(widget.db.workoutExercises,
          widget.db.workoutExercises.id.equalsExp(widget.db.workoutSets.workoutExerciseId)),
      innerJoin(widget.db.workouts,
          widget.db.workouts.id.equalsExp(widget.db.workoutExercises.workoutId)),
    ])
      ..where(
          widget.db.workoutExercises.exerciseId.equals(_selectedExercise!.id) &
          widget.db.workoutSets.isWarmup.equals(false) &
          widget.db.workouts.endedAt.isNotNull() &
          (_selectedGymId != null
              ? widget.db.workouts.gymId.equals(_selectedGymId!)
              : const Constant(true)));

    final results = await query.get();

    double maxWeight = 0;
    DateTime? maxWeightDate;
    double bestE1rm = 0;
    DateTime? bestE1rmDate;
    double maxVolume = 0;
    DateTime? maxVolumeDate;

    for (final row in results) {
      final set = row.readTable(widget.db.workoutSets);
      final workout = row.readTable(widget.db.workouts);

      if (set.weightKg > maxWeight) {
        maxWeight = set.weightKg;
        maxWeightDate = workout.startedAt;
      }
      final e1rm = estimateOneRepMax(set.weightKg, set.reps);
      if (e1rm > bestE1rm) {
        bestE1rm = e1rm;
        bestE1rmDate = workout.startedAt;
      }
      final vol = calculateVolume(set.reps, set.weightKg);
      if (vol > maxVolume) {
        maxVolume = vol;
        maxVolumeDate = workout.startedAt;
      }
    }

    return {
      'maxWeight': maxWeight,
      'maxWeightDate': maxWeightDate,
      'bestE1rm': bestE1rm,
      'bestE1rmDate': bestE1rmDate,
      'maxVolume': maxVolume,
      'maxVolumeDate': maxVolumeDate,
    };
  }

  Future<Map<String, dynamic>> _getDashboardStats() async {
    final workouts = await (widget.db.select(widget.db.workouts)
          ..where((w) =>
              w.endedAt.isNotNull() &
              w.startedAt.isBiggerOrEqualValue(_fromDate) &
              (_selectedGymId != null
                  ? w.gymId.equals(_selectedGymId!)
                  : const Constant(true)))
        ..orderBy([(w) => OrderingTerm.asc(w.startedAt)]))
        .get();

    if (workouts.isEmpty) {
      return {
        'workoutCount': 0,
        'setCount': 0,
        'perWeek': 0.0,
        'totalVolume': 0.0,
        'exerciseCount': 0,
        'days': 0,
      };
    }

    int setCount = 0;
    double totalVolume = 0;
    final exerciseIds = <int>{};

    for (final w in workouts) {
      final wes = await (widget.db.select(widget.db.workoutExercises)
            ..where((we) => we.workoutId.equals(w.id)))
          .get();
      for (final we in wes) {
        exerciseIds.add(we.exerciseId);
        final sets = await (widget.db.select(widget.db.workoutSets)
              ..where((s) =>
                  s.workoutExerciseId.equals(we.id) & s.isWarmup.equals(false)))
            .get();
        setCount += sets.length;
        for (final s in sets) {
          totalVolume += calculateVolume(s.reps, s.weightKg);
        }
      }
    }

    final daysDiff = DateTime.now().difference(workouts.first.startedAt).inDays;
    final weeks = (daysDiff / 7).clamp(1, 999);
    final perWeek = workouts.length / weeks;

    final days = DateTime.now().difference(_fromDate).inDays;

    return {
      'workoutCount': workouts.length,
      'setCount': setCount,
      'perWeek': perWeek,
      'totalVolume': totalVolume,
      'exerciseCount': exerciseIds.length,
      'days': days,
    };
  }

  Future<List<Map<String, dynamic>>> _getMonthlyVolume() async {
    final workouts = await (widget.db.select(widget.db.workouts)
          ..where((w) =>
              w.endedAt.isNotNull() &
              w.startedAt.isBiggerOrEqualValue(_fromDate) &
              (_selectedGymId != null
                  ? w.gymId.equals(_selectedGymId!)
                  : const Constant(true)))
        ..orderBy([(w) => OrderingTerm.asc(w.startedAt)]))
        .get();

    final monthly = <String, Map<String, dynamic>>{};

    for (final w in workouts) {
      final key = '${w.startedAt.year}-${w.startedAt.month.toString().padLeft(2, '0')}';
      final wes = await (widget.db.select(widget.db.workoutExercises)
            ..where((we) => we.workoutId.equals(w.id)))
          .get();

      double vol = 0;
      for (final we in wes) {
        final sets = await (widget.db.select(widget.db.workoutSets)
              ..where((s) =>
                  s.workoutExerciseId.equals(we.id) & s.isWarmup.equals(false)))
            .get();
        for (final s in sets) {
          vol += calculateVolume(s.reps, s.weightKg);
        }
      }

      final existing = monthly[key];
      monthly[key] = {
        'volume': ((existing?['volume'] ?? 0.0) as double) + vol,
        'count': ((existing?['count'] ?? 0) as int) + 1,
      };
    }

    final maxVol = monthly.values
        .fold<double>(0, (max, e) => (e['volume'] as double) > max ? e['volume'] as double : max);

    return monthly.entries.map((e) {
      final parts = e.key.split('-');
      final monthNames = [
        '', 'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
        'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'
      ];
      return {
        'label': '${monthNames[int.parse(parts[1])]} ${parts[0].substring(2)}',
        'volume': e.value['volume'],
        'count': e.value['count'],
        'ratio': maxVol > 0 ? (e.value['volume'] as double) / maxVol : 0.0,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analyse')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int?>(
            initialValue: _selectedGymId,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Alle Studios')),
              for (final g in _gyms)
                DropdownMenuItem(value: g.id, child: Text(g.name)),
            ],
            onChanged: (v) => setState(() => _selectedGymId = v),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip('4W', 28),
              _buildFilterChip('12W', 84),
              _buildFilterChip('6M', 180),
              _buildFilterChip('1J', 365),
              _buildFilterChip('Alle', 9999),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final ex = await showDialog<Exercise>(
                context: context,
                builder: (_) => ExercisePickerDialog(
                  db: widget.db,
                ),
              );
              if (ex != null) setState(() => _selectedExercise = ex);
            },
            icon: const Icon(Icons.fitness_center, size: 18),
            label: Text(_selectedExercise?.name ?? 'Übung auswählen...'),
          ),
          if (_selectedExercise != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _buildMetricChip('e1rm', 'e1RM'),
                _buildMetricChip('volume', 'Volumen'),
                _buildMetricChip('maxWeight', 'Max Gewicht'),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (_selectedExercise != null)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getExerciseData(),
              builder: (context, snap) {
                if (!snap.hasData) return const CircularProgressIndicator();
                final data = snap.data!;
                if (data.isEmpty) return const SizedBox();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_metric == 'e1rm' ? 'e1RM' : _metric == 'volume' ? 'Volumen' : 'Max Gewicht'} — ${_selectedExercise!.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200,
                          child: SimpleLineChart(
                            data: data.map((d) => d[_metric] as double).toList(),
                            labels: data
                                .map((d) => formatDate(d['date'] as DateTime))
                                .toList(),
                          ),
                        ),
                        Text('${data.length} Trainingspunkte',
                            style: const TextStyle(
                                color: AppTheme.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (_selectedExercise != null) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: const Text('Persönliche Rekorde',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 8),
            FutureBuilder<Map<String, dynamic>>(
              future: _getPRs(),
              builder: (context, snap) {
                if (!snap.hasData) return const CircularProgressIndicator();
                final prs = snap.data!;
                return Row(
                  children: [
                    Expanded(
                      child: PRCard(
                        title: 'Max Gewicht',
                        value: '${formatWeight(prs['maxWeight'] as double)} kg',
                        date: prs['maxWeightDate'] != null
                            ? formatDate(prs['maxWeightDate'] as DateTime)
                            : '-',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PRCard(
                        title: 'Beste e1RM',
                        value: '${formatWeight(prs['bestE1rm'] as double)} kg',
                        date: prs['bestE1rmDate'] != null
                            ? formatDate(prs['bestE1rmDate'] as DateTime)
                            : '-',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PRCard(
                        title: 'Max Volumen',
                        value: '${formatVolume(prs['maxVolume'] as double)} kg',
                        date: prs['maxVolumeDate'] != null
                            ? formatDate(prs['maxVolumeDate'] as DateTime)
                            : '-',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: const Text('Dashboard',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>>(
            future: _getDashboardStats(),
            builder: (context, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();
              final stats = snap.data!;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: StatCard(
                              title: 'Trainings',
                              value: '${stats['workoutCount']}',
                              icon: Icons.fitness_center)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: StatCard(
                              title: 'Sätze',
                              value: '${stats['setCount']}',
                              icon: Icons.replay)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: StatCard(
                              title: 'Pro Woche',
                              value: (stats['perWeek'] as double)
                                  .toStringAsFixed(1),
                              icon: Icons.calendar_today)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: StatCard(
                              title: 'Volumen',
                              value:
                                  '${formatVolume(stats['totalVolume'] as double)} kg',
                              icon: Icons.scale)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: StatCard(
                              title: 'Übungen',
                              value: '${stats['exerciseCount']}',
                              icon: Icons.list)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: StatCard(
                              title: 'Zeitraum',
                              value: '${stats['days']} Tage',
                              icon: Icons.date_range)),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: const Text('Monatliches Volumen',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getMonthlyVolume(),
            builder: (context, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();
              final months = snap.data!;
              if (months.isEmpty) return const SizedBox();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      for (final m in months)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(m['label'] as String,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: m['ratio'] as double,
                                  backgroundColor: AppTheme.surfaceVariant,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: Text(
                                    '${formatVolume(m['volume'] as double)} kg',
                                    style: const TextStyle(fontSize: 12),
                                    textAlign: TextAlign.right),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 30,
                                child: Text('(${m['count']})',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppTheme.muted),
                                    textAlign: TextAlign.right),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int days) {
    return ChoiceChip(
      label: Text(label),
      selected: _daysFilter == days,
      onSelected: (_) => setState(() => _daysFilter = days),
    );
  }

  Widget _buildMetricChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _metric == value,
      onSelected: (_) => setState(() => _metric = value),
    );
  }
}
