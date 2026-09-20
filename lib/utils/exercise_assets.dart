import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants.dart';

const Map<String, String> exerciseImageAssets = {
  'ab-wheel-rollout': 'assets/exercises/ab-wheel-rollout.webp',
  'back-extension': 'assets/exercises/back-extension.webp',
  'barbell-row': 'assets/exercises/barbell-row.webp',
  'bench-press': 'assets/exercises/bench-press.webp',
  'bulgarian-split-squat': 'assets/exercises/bulgarian-split-squat.webp',
  'cable-bent-over-row': 'assets/exercises/cable-bent-over-row.webp',
  'cable-crossover': 'assets/exercises/cable-crossover.webp',
  'cable-curl': 'assets/exercises/cable-curl.webp',
  'calf-raise': 'assets/exercises/calf-raise.webp',
  'chest-fly': 'assets/exercises/chest-fly.webp',
  'chest-press': 'assets/exercises/chest-press.webp',
  'crunch': 'assets/exercises/crunch.webp',
  'face-pull': 'assets/exercises/face-pull.webp',
  'front-raise': 'assets/exercises/front-raise.webp',
  'hack-squat': 'assets/exercises/hack-squat.webp',
  'hammer-curl': 'assets/exercises/hammer-curl.webp',
  'hanging-leg-raise': 'assets/exercises/hanging-leg-raise.webp',
  'hip-thrust': 'assets/exercises/hip-thrust.webp',
  'incline-bench-press': 'assets/exercises/incline-bench-press.webp',
  'lateral-raise': 'assets/exercises/lateral-raise.webp',
  'lat-pulldown': 'assets/exercises/lat-pulldown.webp',
  'leg-curl': 'assets/exercises/leg-curl.webp',
  'leg-extension': 'assets/exercises/leg-extension.webp',
  'leg-press': 'assets/exercises/leg-press.webp',
  'lunge': 'assets/exercises/lunge.webp',
  'plank': 'assets/exercises/plank.webp',
  'preacher-curl': 'assets/exercises/preacher-curl.webp',
  'pull-up': 'assets/exercises/pull-up.webp',
  'romanian-deadlift': 'assets/exercises/romanian-deadlift.webp',
  'running': 'assets/exercises/running.webp',
  'russian-twist': 'assets/exercises/russian-twist.webp',
  'seated-row': 'assets/exercises/seated-row.webp',
  'shoulder-press': 'assets/exercises/shoulder-press.webp',
  'skull-crusher': 'assets/exercises/skull-crusher.webp',
  'squat': 'assets/exercises/squat.webp',
  'stationary-bike': 'assets/exercises/stationary-bike.webp',
  'tricep-pushdown': 'assets/exercises/tricep-pushdown.webp',
  'wrist-curl': 'assets/exercises/wrist-curl.webp',
};

const Map<String, String> _germanToKey = {
  'hackenschmidt': 'hack-squat',
  'hack squat': 'hack-squat',
  'hackschmitt': 'hack-squat',
  'hip thrust machine': 'hip-thrust',
  'hip thrust': 'hip-thrust',
  'beinpresse horizontal': 'leg-press',
  'beinpresse 45': 'leg-press',
  'beinpresse': 'leg-press',
  'wadenpresse horizontal': 'calf-raise',
  'wadenpresse 45': 'calf-raise',
  'wadenheber sitzend': 'calf-raise',
  'wadenmaschine': 'calf-raise',
  'beinstrecker': 'leg-extension',
  'beinbeuger': 'leg-curl',
  'beinbeuger liegend': 'leg-curl',
  'brustpresse': 'chest-press',
  'brust': 'chest-press',
  'brustfly': 'chest-fly',
  'chest fly': 'chest-fly',
  'schulterpresse': 'shoulder-press',
  'schulter': 'shoulder-press',
  'seitheben': 'lateral-raise',
  'trizeps skull crush': 'skull-crusher',
  'skullcrusher': 'skull-crusher',
  'trizeps kabelzug': 'tricep-pushdown',
  'trizeps': 'tricep-pushdown',
  'latzug': 'lat-pulldown',
  'lat pulldown': 'lat-pulldown',
  'rudern brustgestützt': 'cable-bent-over-row',
  'rudern': 'barbell-row',
  'face pulls': 'face-pull',
  'face pull': 'face-pull',
  'bizeps hammer curls': 'hammer-curl',
  'hammer curls': 'hammer-curl',
  'bizeps kabelzug': 'cable-curl',
  'bizeps': 'hammer-curl',
  'hyperextension': 'back-extension',
  'rückenstreckung': 'back-extension',
  'bauchmaschine': 'crunch',
  'bauch': 'crunch',
  'unterarm-innencurls': 'wrist-curl',
  'unterarm-außencurls': 'wrist-curl',
  'unterarm': 'wrist-curl',
  'squat': 'squat',
  'kniebeuge': 'squat',
  'deadlift': 'romanian-deadlift',
  'kreuzheben': 'romanian-deadlift',
  'bench press': 'bench-press',
  'bankdrücken': 'bench-press',
  'schrägbank': 'incline-bench-press',
  'incline bench': 'incline-bench-press',
  'dips': 'chest-press',
  'pull up': 'pull-up',
  'klimmzug': 'pull-up',
  'pull-down': 'lat-pulldown',
  'military press': 'shoulder-press',
  'overhead press': 'shoulder-press',
  'barbell row': 'barbell-row',
  'dumbbell row': 'barbell-row',
  'romanian deadlift': 'romanian-deadlift',
  'bulgarian split squat': 'bulgarian-split-squat',
  'lunge': 'lunge',
  'calf raise': 'calf-raise',
  'wadenheber': 'calf-raise',
  'front raise': 'front-raise',
  'seitenheben': 'lateral-raise',
  'shrug': 'shrug',
  'preacher curl': 'preacher-curl',
  'preacher': 'preacher-curl',
  'cable fly': 'cable-crossover',
  'pec deck': 'chest-fly',
  'plank': 'plank',
  'hanging leg raise': 'hanging-leg-raise',
  'russian twist': 'russian-twist',
  'ab wheel': 'ab-wheel-rollout',
  'bauchroller': 'ab-wheel-rollout',
  'dumbbell curl': 'hammer-curl',
  'curl': 'hammer-curl',
  'leg curl': 'leg-curl',
  'leg extension': 'leg-extension',
  'seated cable row': 'seated-row',
  'cable row': 'seated-row',
  'wrist curl': 'wrist-curl',
  'laufen': 'running',
  'joggen': 'running',
  'treadmill': 'running',
  'laufband': 'running',
  'bike': 'stationary-bike',
  'fahrrad': 'stationary-bike',
  'ergometer': 'stationary-bike',
  'rad': 'stationary-bike',
};

String? getExerciseImage(String exerciseName) {
  final nameLower = exerciseName.toLowerCase().trim();

  if (exerciseImageAssets.containsKey(nameLower)) {
    return exerciseImageAssets[nameLower];
  }

  if (_germanToKey.containsKey(nameLower)) {
    return exerciseImageAssets[_germanToKey[nameLower]];
  }

  for (final entry in _germanToKey.entries) {
    if (nameLower.contains(entry.key) || entry.key.contains(nameLower)) {
      return exerciseImageAssets[entry.value];
    }
  }

  for (final key in exerciseImageAssets.keys) {
    if (nameLower.contains(key) || key.contains(nameLower)) {
      return exerciseImageAssets[key];
    }
  }

  return null;
}

bool hasExerciseImage(String exerciseName) {
  return getExerciseImage(exerciseName) != null;
}

String? getIconAsset(String iconKey) {
  final key = iconKey.toLowerCase().trim();

  final directPath = 'assets/exercises/$key.webp';
  if (exerciseImageAssets.containsValue(directPath)) {
    return directPath;
  }

  if (exerciseImageAssets.containsKey(key)) {
    return exerciseImageAssets[key];
  }

  if (_germanToKey.containsKey(key)) {
    return exerciseImageAssets[_germanToKey[key]];
  }

  return null;
}

class IconOption {
  final String key;
  final String label;
  final String? imagePath;
  final String? category;
  final String? equipment;
  final String? bodyPart;

  const IconOption({
    required this.key,
    required this.label,
    this.imagePath,
    this.category,
    this.equipment,
    this.bodyPart,
  });
}

List<IconOption>? _cachedOptions;

Future<List<IconOption>> getAllIconOptions() async {
  if (_cachedOptions != null) return _cachedOptions!;

  final jsonStr = await rootBundle.loadString('assets/exercises/exercises_meta.json');
  final List<dynamic> meta = json.decode(jsonStr);

  final options = <IconOption>[];
  for (final entry in meta) {
    final id = entry['id'] as String;
    final imagePath = 'assets/exercises/$id.webp';
    options.add(IconOption(
      key: id,
      label: entry['name_de'] ?? entry['name_en'] ?? id,
      imagePath: imagePath,
      category: entry['category'] as String?,
      equipment: entry['equipment'] as String?,
      bodyPart: entry['body_part'] as String?,
    ));
  }

  _cachedOptions = options;
  return options;
}

List<IconOption> filterIconOptions(List<IconOption> options, String query) {
  if (query.isEmpty) return options;
  final q = query.toLowerCase();
  return options.where((o) =>
    o.label.toLowerCase().contains(q) ||
    o.key.toLowerCase().contains(q) ||
    (o.equipment?.toLowerCase().contains(q) ?? false) ||
    (o.bodyPart?.toLowerCase().contains(q) ?? false) ||
    (o.category?.toLowerCase().contains(q) ?? false)
  ).toList();
}
