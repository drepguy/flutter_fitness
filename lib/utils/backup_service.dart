import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import 'export_service.dart';
import 'import_service.dart';

class BackupService {
  final AppDatabase db;

  BackupService(this.db);

  static const _autoBackupKey = 'auto_backup_enabled';

  Future<Directory> get _backupDir async {
    final dir = Directory('/storage/emulated/0/Documents/Flutter_Fitness');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupKey) ?? true;
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupKey, enabled);
  }

  Future<File> saveBackup() async {
    final exportService = ExportService(db);
    final json = await exportService.buildJson();

    final dir = await _backupDir;
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final file = File('${dir.path}/backup_$timestamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));

    return file;
  }

  Future<bool> backupExistsForToday() async {
    final dir = await _backupDir;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final files = await dir.list().where((f) => f.path.contains(today)).toList();
    return files.isNotEmpty;
  }

  Future<void> autoBackupIfNeeded() async {
    if (!await isAutoBackupEnabled()) return;
    if (await backupExistsForToday()) return;
    await saveBackup();
  }

  Future<List<BackupEntry>> listBackups() async {
    final dir = await _backupDir;
    if (!await dir.exists()) return [];

    final files = await dir
        .list()
        .where((f) => f is File && f.path.endsWith('.json'))
        .cast<File>()
        .toList();

    files.sort((a, b) => b.path.compareTo(a.path));

    final entries = <BackupEntry>[];
    for (final file in files) {
      final stat = await file.stat();
      final name = file.path.split(Platform.pathSeparator).last;
      entries.add(BackupEntry(
        file: file,
        name: name,
        size: stat.size,
        modified: stat.modified,
      ));
    }
    return entries;
  }

  Future<void> restoreBackup(File file) async {
    final content = await file.readAsString();
    final importService = ImportService(db);
    await importService.importJson(content);
  }

  Future<void> deleteBackup(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class BackupEntry {
  final File file;
  final String name;
  final int size;
  final DateTime modified;

  BackupEntry({
    required this.file,
    required this.name,
    required this.size,
    required this.modified,
  });

  String get sizeLabel {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get dateLabel => DateFormat('dd.MM.yyyy, HH:mm').format(modified);
}
