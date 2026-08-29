import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column, Index;
import '../database/app_database.dart';

class GymEditDialog extends StatefulWidget {
  final AppDatabase db;
  final Gym? gym;

  const GymEditDialog({super.key, required this.db, this.gym});

  @override
  State<GymEditDialog> createState() => _GymEditDialogState();
}

class _GymEditDialogState extends State<GymEditDialog> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.gym != null) {
      _nameController.text = widget.gym!.name;
      _cityController.text = widget.gym!.city ?? '';
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;

    if (widget.gym != null) {
      await (widget.db.update(widget.db.gyms)
            ..where((g) => g.id.equals(widget.gym!.id)))
          .write(GymsCompanion(
        name: Value(_nameController.text.trim()),
        city: Value(_cityController.text.isEmpty ? null : _cityController.text.trim()),
      ));
    } else {
      await widget.db.into(widget.db.gyms).insert(
            GymsCompanion.insert(
              name: _nameController.text.trim(),
              city: Value(_cityController.text.isEmpty ? null : _cityController.text.trim()),
              createdAt: DateTime.now(),
            ),
          );
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.gym != null ? 'Studio bearbeiten' : 'Neues Studio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cityController,
            decoration: const InputDecoration(labelText: 'Stadt (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
