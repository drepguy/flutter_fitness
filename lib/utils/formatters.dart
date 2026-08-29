import 'package:intl/intl.dart';

String formatDateTime(DateTime dt) {
  return DateFormat('dd.MM.yyyy HH:mm').format(dt);
}

String formatDate(DateTime dt) {
  return DateFormat('dd.MM.yyyy').format(dt);
}

String formatTime(DateTime dt) {
  return DateFormat('HH:mm').format(dt);
}

String formatWeight(double kg) {
  return kg.toStringAsFixed(1);
}

String formatVolume(double vol) {
  if (vol >= 1000) {
    return '${(vol / 1000).toStringAsFixed(1)}k';
  }
  return vol.toStringAsFixed(0);
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
