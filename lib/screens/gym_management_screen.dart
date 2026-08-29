import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../theme/app_theme.dart';
import '../widgets/gym_edit_dialog.dart';

class GymManagementScreen extends StatefulWidget {
  final AppDatabase db;

  const GymManagementScreen({super.key, required this.db});

  @override
  State<GymManagementScreen> createState() => _GymManagementScreenState();
}

class _GymManagementScreenState extends State<GymManagementScreen> {
  List<Gym> _gyms = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final gyms = await widget.db.select(widget.db.gyms).get();
    setState(() => _gyms = gyms);
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
      appBar: AppBar(title: const Text('Studios verwalten')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
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
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (gym.isSystem)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      style:
                          const TextStyle(color: AppTheme.muted, fontSize: 13))
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceContainerHigh,
        ),
        child: OutlinedButton.icon(
          onPressed: _addGym,
          icon: const Icon(Icons.add),
          label: const Text('Neues Studio'),
        ),
      ),
    );
  }
}
