import 'package:flutter/material.dart';

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
  'barbell': 'Langhantel',
  'bench': 'Bank',
  'leg_press': 'Beine',
  'cable': 'Kabelzug',
  'pull_up': 'Klimmzug',
  'treadmill': 'Laufband',
  'bike': 'Fahrrad',
  'rowing': 'Rudern',
  'shoulder': 'Schulter',
  'arm': 'Arm',
  'core': 'Core',
  'cardio': 'Cardio',
};

const Map<String, IconData> iconData = {
  'dumbbell': Icons.fitness_center,
  'barbell': Icons.sports_gymnastics,
  'bench': Icons.airline_seat_flat,
  'leg_press': Icons.directions_walk,
  'cable': Icons.cable,
  'pull_up': Icons.accessibility_new,
  'treadmill': Icons.directions_run,
  'bike': Icons.directions_bike,
  'rowing': Icons.rowing,
  'shoulder': Icons.back_hand,
  'arm': Icons.front_hand,
  'core': Icons.self_improvement,
  'cardio': Icons.favorite,
};

String autoAssignIconKey(String name, String category) {
  final n = name.toLowerCase();
  final c = category.toLowerCase();

  if (n.contains('bankdrücken') || n.contains('bench press') || n.contains('fliegend') || n.contains('schrägbank') || n.contains('dips')) return 'bench';
  if (n.contains('kniebeuge') || n.contains('squat') || n.contains('beinbeuger') || n.contains('beinstrecker') || n.contains('waden') || n.contains('beinpresse') || n.contains('hack')) return 'leg_press';
  if (n.contains('rudern') || n.contains('rowing') || n.contains('bell row')) return 'rowing';
  if (n.contains('kreuzheben') || n.contains('deadlift')) return 'barbell';
  if (n.contains('latzug') || n.contains('lat pulldown') || n.contains('klimmzug') || n.contains('pull up') || n.contains('pull-down')) return 'pull_up';
  if (n.contains('curl') || n.contains('bizeps') || n.contains('biceps')) return 'arm';
  if (n.contains('trizeps') || n.contains('triceps') || n.contains('pushdown')) return 'arm';
  if (n.contains('schulter') || n.contains('shoulder') || (n.contains('drücken') && c == 'schulter')) return 'shoulder';
  if (n.contains('laufband') || n.contains('treadmill') || n.contains('joggen') || n.contains('laufen')) return 'treadmill';
  if (n.contains('rad') || n.contains('bike') || n.contains('fahrrad') || n.contains('ergometer')) return 'bike';
  if (n.contains('cable') || n.contains('kabel') || n.contains('seilzug') || n.contains('ziehen')) return 'cable';
  if (n.contains('bauch') || n.contains('crunch') || n.contains('plank') || n.contains('core')) return 'core';
  if (n.contains('cardio') || n.contains('springen') || n.contains('seil')) return 'cardio';

  if (c == 'brust') return 'bench';
  if (c == 'rücken') return 'rowing';
  if (c == 'beine') return 'leg_press';
  if (c == 'schulter') return 'shoulder';
  if (c == 'arme') return 'arm';
  if (c == 'core') return 'core';
  if (c == 'cardio') return 'cardio';
  if (c == 'unterarme') return 'arm';
  if (c == 'ganzkörper') return 'barbell';

  return 'dumbbell';
}

double estimateOneRepMax(double weight, int reps) {
  if (weight <= 0 || reps <= 0) return 0;
  return weight * (1 + reps / 30.0);
}

double calculateVolume(int reps, double weightKg) {
  return reps * weightKg;
}
