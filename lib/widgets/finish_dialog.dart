import 'package:flutter/material.dart';

class FinishDialog extends StatefulWidget {
  final int exerciseCount;
  final int setCount;

  const FinishDialog({
    super.key,
    required this.exerciseCount,
    required this.setCount,
  });

  @override
  State<FinishDialog> createState() => _FinishDialogState();
}

class _FinishDialogState extends State<FinishDialog> {
  final _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Training beenden?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.exerciseCount} Übungen, ${widget.setCount} Sätze'),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notizen (optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Weiter trainieren'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'notes': _notesController.text.isEmpty ? null : _notesController.text,
          }),
          child: const Text('Speichern & Beenden'),
        ),
      ],
    );
  }
}
