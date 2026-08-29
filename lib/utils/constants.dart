const List<String> exerciseCategories = [
  'Brust',
  'Rücken',
  'Beine',
  'Schulter',
  'Arme',
  'Core',
  'Ganzkörper',
  'Cardio',
  'Unterarme',
  'Sonstiges',
];

const Map<String, String> exerciseKindLabels = {
  'machine': 'Maschine',
  'free_weight': 'Freigewicht',
  'cable': 'Kabelzug',
  'bodyweight': 'Körpergewicht',
};

const Map<String, String> iconLabels = {
  'dumbbell': 'Hantel',
  'leg_press': 'Beine',
  'barbell': 'Langhantel',
  'cable': 'Kabelzug',
  'bench': 'Bank',
  'pull_up': 'Klimmzug',
  'treadmill': 'Laufband',
  'bike': 'Fahrrad',
};

double estimateOneRepMax(double weight, int reps) {
  if (weight <= 0 || reps <= 0) return 0;
  return weight * (1 + reps / 30.0);
}

double calculateVolume(int reps, double weightKg) {
  return reps * weightKg;
}
