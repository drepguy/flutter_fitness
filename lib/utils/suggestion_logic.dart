/// Pure selection logic for the "Empfohlen" next-exercise suggestion.
///
/// Deliberately free of Drift/Flutter imports: callers resolve IDs to rows,
/// this library only decides *which* workout or exercise wins. Every caller
/// passes data scoped to a single gym — suggestions must never cross gym
/// boundaries, because exercise availability differs per gym.
library;

/// Containment score: share of [todayIds] that also appears in [pastIds].
///
/// Returns 0.0 for an empty [todayIds] so an empty session can never match
/// by accident.
double dayMatchScore(Set<int> todayIds, List<int> pastIds) {
  if (todayIds.isEmpty) return 0.0;
  final past = pastIds.toSet();
  final overlap = todayIds.where(past.contains).length;
  return overlap / todayIds.length;
}

/// Index of the workout in [pastWorkouts] that best matches [todayIds] by
/// [dayMatchScore], or `null` when no workout contains any of today's
/// exercises.
///
/// [pastWorkouts] must be ordered newest-first: ties keep the earlier
/// entry, so the more recent workout wins.
int? findBestDayMatch(Set<int> todayIds, List<List<int>> pastWorkouts) {
  var bestIndex = -1;
  var bestScore = 0.0;
  for (var i = 0; i < pastWorkouts.length; i++) {
    final score = dayMatchScore(todayIds, pastWorkouts[i]);
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }
  return bestIndex < 0 ? null : bestIndex;
}

/// First exercise after [anchorId] in [orderedIds] that is not in [doneIds]
/// yet, or `null` when the anchor is unknown or everything after it is done.
int? nextAfterAnchor(int anchorId, List<int> orderedIds, Set<int> doneIds) {
  final start = orderedIds.indexOf(anchorId);
  if (start < 0) return null;
  for (var i = start + 1; i < orderedIds.length; i++) {
    final id = orderedIds[i];
    if (!doneIds.contains(id)) return id;
  }
  return null;
}

/// Exercise directly after the first occurrence of [anchorId] in
/// [orderedIds], or `null` when the anchor is unknown or ends the list.
int? immediateSuccessor(int anchorId, List<int> orderedIds) {
  final index = orderedIds.indexOf(anchorId);
  if (index < 0 || index + 1 >= orderedIds.length) return null;
  return orderedIds[index + 1];
}

/// Exercise that most often directly follows the anchor across history.
///
/// [successors] holds one immediate successor per historical workout,
/// newest first (`null` when the anchor ended that workout). Successors
/// already in [doneIds] are ignored. Ties keep the candidate seen in the
/// newest workout (earliest entry). Returns `null` when no candidate
/// remains.
int? mostCommonSuccessor(List<int?> successors, Set<int> doneIds) {
  final counts = <int, int>{};
  final firstIndex = <int, int>{};
  for (var i = 0; i < successors.length; i++) {
    final successor = successors[i];
    if (successor == null || doneIds.contains(successor)) continue;
    counts[successor] = (counts[successor] ?? 0) + 1;
    firstIndex.putIfAbsent(successor, () => i);
  }
  if (counts.isEmpty) return null;

  int? best;
  var bestCount = 0;
  var bestSeenAt = 0;
  for (final entry in counts.entries) {
    final seenAt = firstIndex[entry.key]!;
    if (best == null ||
        entry.value > bestCount ||
        (entry.value == bestCount && seenAt < bestSeenAt)) {
      best = entry.key;
      bestCount = entry.value;
      bestSeenAt = seenAt;
    }
  }
  return best;
}

/// First exercise of [orderedIds] not present in [doneIds], or `null`.
int? firstNotDone(List<int> orderedIds, Set<int> doneIds) {
  for (final id in orderedIds) {
    if (!doneIds.contains(id)) return id;
  }
  return null;
}
