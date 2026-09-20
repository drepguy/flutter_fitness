const Map<String, String> exerciseImageAssets = {
  'ab-wheel-rollout': 'assets/exercises/ab-wheel-rollout.webp',
  'back-extension': 'assets/exercises/back-extension.webp',
  'barbell-row': 'assets/exercises/barbell-row.webp',
  'bench-press': 'assets/exercises/bench-press.webp',
  'bulgarian-split-squat': 'assets/exercises/bulgarian-split-squat.webp',
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
  'wrist-curl': 'assets/exercises/wrist-curl.webp',
};

final Map<String, String> _germanToKey = {
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
  'trizeps kabelzug': 'triceps-pushdown',
  'trizeps': 'triceps-pushdown',
  'latzug': 'lat-pulldown',
  'lat pulldown': 'lat-pulldown',
  'rudern brustgestützt': 'chest-supported-row',
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
  'beinbeuger': 'leg-curl',
  'leg extension': 'leg-extension',
  'beinstrecker': 'leg-extension',
  'seated cable row': 'seated-row',
  'cable row': 'seated-row',
  'lat pulldown': 'lat-pulldown',
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
