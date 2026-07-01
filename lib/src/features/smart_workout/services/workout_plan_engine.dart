import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gym/data/exercises_repository.dart';
import '../../gym/models/exercise_model.dart';
import '../../profile/providers/body_metrics_provider.dart';
import '../models/routine_model.dart';
import '../providers/split_setup_provider.dart';

/// Per-player training profile derived from InBody / body-composition data.
/// Personalizes the plan beyond the experience level so two players at the same
/// level don't get identical workouts.
class TrainingProfile {
  /// Raw goal string from the player's metrics (e.g. "loseFat", "Build Muscle").
  final String goal;
  final double bodyFat; // %
  final double bmi;
  final String gender;

  /// Player's age in years (0 = unknown). Used alongside body composition for
  /// the physical-safety gate: some exercise types carry meaningfully higher
  /// injury/joint-stress risk for older players regardless of training
  /// experience (e.g. Olympic lifts, high-impact jumping).
  final int age;

  /// Muscle mass in kg (0 = unknown) and body weight in kg (0 = unknown).
  /// Together with [bodyFat] these let the physical-safety gate tell apart a
  /// heavily-muscled high-BMI athlete from a high-BMI player carrying excess
  /// fat — BMI alone can't distinguish the two, but body fat % + muscle mass
  /// can.
  final double muscleMass;
  final double weight;

  /// Deterministic per-player seed (e.g. from the user id) used to vary which
  /// exercises are picked. Same player => same plan; different players differ.
  final int seed;

  /// Per-exercise best/last weight (exercise name -> kg) from the player's
  /// history. Drives progressive overload: suggested weights track and gently
  /// push the player's real numbers, so the plan keeps progressing over time.
  final Map<String, double> history;

  const TrainingProfile({
    this.goal = '',
    this.bodyFat = 0,
    this.bmi = 0,
    this.gender = '',
    this.age = 0,
    this.muscleMass = 0,
    this.weight = 0,
    this.seed = 0,
    this.history = const {},
  });

  static const TrainingProfile none = TrainingProfile();

  /// Builds a profile from the player's body-composition (InBody) metrics.
  /// [seed] should be stable per player (e.g. the user id hash) so the plan is
  /// reproducible for that player but differs between players. [history] maps
  /// exercise name -> best weight for progressive overload.
  factory TrainingProfile.fromMetrics(
    BodyMetrics m, {
    required int seed,
    Map<String, double> history = const {},
  }) {
    return TrainingProfile(
      goal: m.goal,
      bodyFat: m.bodyFat,
      bmi: m.bmi,
      gender: m.gender,
      age: m.age,
      muscleMass: m.muscleMass,
      weight: m.weight,
      seed: seed,
      history: history,
    );
  }

  bool get _isFemale => gender.trim().toLowerCase().startsWith('f');

  /// Ratio of muscle mass to total body weight (0 when unknown). A high ratio
  /// (rule of thumb: ~45%+) signals an athletic/heavily-muscled build rather
  /// than excess fat mass.
  double get _muscleMassRatio => weight > 0 ? muscleMass / weight : 0;

  /// True when the player's *fat mass* (not just total mass) is high enough
  /// to carry meaningfully higher joint-loading risk, independent of training
  /// experience. Body fat % is the direct, gender-aware measure (ACE
  /// classification: ~25%+ for men, ~32%+ for women is the "obese" category)
  /// — this is more accurate than BMI alone, which can't tell a muscular
  /// heavy player from a fat-heavy one at the same body mass.
  ///
  /// Falls back to BMI ≥ 30 only when no body-fat scan is available, and even
  /// then skips the flag for players with a high muscle-mass ratio (their
  /// extra mass is muscle, not fat).
  bool get isHighAdiposity {
    if (bodyFat > 0) {
      final threshold = _isFemale ? 32.0 : 25.0;
      return bodyFat >= threshold;
    }
    if (bmi <= 0) return false;
    if (_muscleMassRatio >= 0.45) return false; // heavily muscled, not fat.
    return bmi >= 30.0;
  }

  /// Normalized training intent: 'fat_loss' | 'muscle_gain' | 'recomp' | 'maintain'.
  /// Falls back to inferring from body-fat % when the goal is unknown.
  String get normalizedGoal {
    final g = goal.toLowerCase();
    if (g.contains('fat') ||
        g.contains('lose') ||
        g.contains('cut') ||
        g.contains('weight') ||
        g.contains('سمن') ||
        g.contains('دهون') ||
        g.contains('تنشيف') ||
        g.contains('نحف') ||
        g.contains('وزن')) {
      return 'fat_loss';
    }
    if (g.contains('muscle') ||
        g.contains('build') ||
        g.contains('gain') ||
        g.contains('bulk') ||
        g.contains('عضل') ||
        g.contains('ضخام') ||
        g.contains('تضخيم')) {
      return 'muscle_gain';
    }
    if (g.contains('maintain') || g.contains('حفاظ') || g.contains('ثبات')) {
      return 'maintain';
    }
    if (g.contains('fit') || g.contains('recomp') || g.contains('لياقة')) {
      return 'recomp';
    }
    // Infer from body fat when the goal text is unknown/empty.
    if (bodyFat > 0) {
      final highBf = _isFemale ? 32.0 : 24.0;
      final lowBf = _isFemale ? 23.0 : 14.0;
      if (bodyFat >= highBf) return 'fat_loss';
      if (bodyFat <= lowBf) return 'muscle_gain';
    }
    return 'recomp';
  }
}

/// Result of generating a workout plan: the 7-day schedule plus the generated
/// routines (keyed by their generated id) that the schedule days point to.
class WorkoutPlanResult {
  final List<WorkoutDay> days;
  final Map<String, RoutineModel> routines;

  const WorkoutPlanResult({required this.days, required this.routines});

  static const WorkoutPlanResult empty =
      WorkoutPlanResult(days: <WorkoutDay>[], routines: {});
}

/// Builds level-aware, full-coverage workout plans directly from the real
/// exercise database (Firebase `exercises`, grouped by MuscleGroup).
///
/// Guarantees:
///  * Exercises only come from the catalog (never random / invented).
///  * Exercises respect the player's level using a *cumulative ceiling*:
///      beginner     -> Beginner
///      intermediate -> Beginner + Intermediate
///      advanced     -> Beginner + Intermediate + Advanced
///  * Every muscle group is trained at least once across the training week
///    (a gap-fill pass adds any muscle the split would otherwise miss).
///  * Sets / reps / rest scale with the player's level.
class WorkoutPlanEngine {
  /// Canonical Firebase MuscleGroup names.
  static const List<String> allMuscles = [
    'Chest',
    'Back',
    'Shoulders',
    'Legs',
    'Traps',
    'Triceps',
    'Biceps',
    'Abs',
    'Forearms',
  ];

  /// Maps a split "category" (e.g. Push) to the Firebase muscle groups it hits.
  static const Map<String, List<String>> _categoryMuscles = {
    'Push': ['Chest', 'Shoulders', 'Triceps'],
    'Pull': ['Back', 'Biceps', 'Traps', 'Forearms'],
    'Upper Body': [
      'Chest',
      'Back',
      'Shoulders',
      'Biceps',
      'Triceps',
      'Traps',
      'Forearms',
    ],
    'Lower Body': ['Legs', 'Abs'],
    'Full Body': [
      'Legs',
      'Chest',
      'Back',
      'Shoulders',
      'Biceps',
      'Triceps',
      'Abs',
      'Traps',
      'Forearms',
    ],
    'Arms': ['Biceps', 'Triceps', 'Forearms'],
    'Shoulders & Arms': ['Shoulders', 'Biceps', 'Triceps'],
    'Chest': ['Chest'],
    'Back': ['Back', 'Traps'],
    'Shoulders': ['Shoulders'],
    'Legs': ['Legs', 'Abs'],
  };

  static const List<String> _weekdays = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  /// Normalizes any stored value to one of beginner/intermediate/advanced.
  static String normalizeLevel(String level) {
    final l = level.trim().toLowerCase();
    if (l.startsWith('adv')) return 'advanced';
    if (l.startsWith('int')) return 'intermediate';
    return 'beginner';
  }

  /// Cumulative ceiling: which ExperienceLevel buckets a level may draw from.
  static List<String> _allowedExperienceLevels(String level) {
    switch (normalizeLevel(level)) {
      case 'advanced':
        return const ['Beginner', 'Intermediate', 'Advanced'];
      case 'intermediate':
        return const ['Beginner', 'Intermediate'];
      default:
        return const ['Beginner'];
    }
  }

  /// Exercise types that require advanced coordination/technique or carry
  /// meaningfully higher injury risk (Olympic lifts, plyometric jumps,
  /// max-effort powerlifting/strongman work) — reserved for Advanced players
  /// ONLY, regardless of what the source data's ExperienceLevel field says.
  ///
  /// This exists because the catalog's ExperienceLevel tagging is unreliable
  /// for these types: e.g. several Kettlebell Clean & Press / Box Jump /
  /// Suitcase Deadlift entries are mislabeled "Beginner" in the raw data even
  /// though they're not appropriate first exercises for a new player.
  static const Set<String> _advancedOnlyTypes = {
    'olympic weightlifting',
    'plyometrics',
    'powerlifting',
    'strongman',
  };

  static bool _isAdvancedOnlyType(ExerciseModel e) =>
      _advancedOnlyTypes.contains(e.exerciseType.trim().toLowerCase());

  /// True when [e] is safe to surface for [level] once the advanced-only
  /// exercise-type gate is applied on top of the normal ExperienceLevel check.
  static bool _passesSafetyGate(ExerciseModel e, String level) =>
      normalizeLevel(level) == 'advanced' || !_isAdvancedOnlyType(e);

  /// Age (years) at/above which Olympic lifts and plyometric/jump work are
  /// excluded for EVERY level — these need high technical coaching load
  /// (Olympic lifts) or high joint impact (plyometrics) that general
  /// older-adult exercise guidelines advise against regardless of how long
  /// someone has trained.
  static const int _highRiskAgeCeiling = 60;

  /// Physical-safety gate: unlike [_passesSafetyGate] (which only relaxes as
  /// the player's *experience level* rises), this gate is driven by the
  /// player's *body* and cannot be unlocked by leveling up — a player with
  /// high fat mass (see [TrainingProfile.isHighAdiposity], which uses body
  /// fat % + muscle mass rather than raw BMI so a muscular heavy player isn't
  /// mistaken for an overweight one) or an older player stays excluded from
  /// these exercise types even at Advanced.
  static bool _passesPhysicalSafetyGate(
    ExerciseModel e, {
    required bool highAdiposity,
    required int age,
  }) {
    final type = e.exerciseType.trim().toLowerCase();
    if (highAdiposity && type == 'plyometrics') return false;
    if (age >= _highRiskAgeCeiling &&
        (type == 'plyometrics' || type == 'olympic weightlifting')) {
      return false;
    }
    return true;
  }

  // Per-level training volume.
  static int _dayTarget(String level) {
    switch (normalizeLevel(level)) {
      case 'advanced':
        return 10;
      case 'intermediate':
        return 8;
      default:
        return 6;
    }
  }

  static int _perMuscleCap(String level) {
    switch (normalizeLevel(level)) {
      case 'advanced':
        return 4;
      case 'intermediate':
        return 3;
      default:
        return 2;
    }
  }

  static int _focalSets(String level) {
    switch (normalizeLevel(level)) {
      case 'advanced':
        return 5;
      case 'intermediate':
        return 4;
      default:
        return 3;
    }
  }

  static int _normalSets(String level) {
    switch (normalizeLevel(level)) {
      case 'advanced':
        return 4;
      default:
        return 3;
    }
  }

  // Reps/rest combine the experience level with the player's GOAL:
  //  * fat_loss     -> higher reps, shorter rest (more density / conditioning)
  //  * muscle_gain  -> moderate/heavier reps, longer rest
  //  * recomp/maintain -> level default
  static String _reps(String level, String goal, bool focal) {
    switch (goal) {
      case 'fat_loss':
        return focal ? '12-15' : '15-20';
      case 'muscle_gain':
        switch (normalizeLevel(level)) {
          case 'advanced':
            return focal ? '6-8' : '8-12';
          case 'intermediate':
            return focal ? '8-10' : '10-12';
          default:
            return focal ? '10-12' : '12-15';
        }
      default: // recomp / maintain
        switch (normalizeLevel(level)) {
          case 'advanced':
            return '6-10';
          case 'intermediate':
            return '8-12';
          default:
            return '10-12';
        }
    }
  }

  static int _rest(String level, String goal, bool focal) {
    switch (goal) {
      case 'fat_loss':
        return 45;
      case 'muscle_gain':
        return focal ? 90 : 75;
      default:
        return normalizeLevel(level) == 'advanced' ? 60 : 75;
    }
  }

  /// Ordered list of muscle-category groups per training day for a given split.
  static List<List<String>> _categoryMapping(int days, String splitType) {
    var split = splitType;
    if (split == 'ai_decide' || split == 'ai') {
      if (days <= 3) {
        split = 'fb';
      } else if (days == 4) {
        split = 'ul';
      } else if (days == 5) {
        split = 'bro_split';
      } else {
        split = 'ppl';
      }
    }

    if (split == 'ppl') {
      if (days >= 3) return [['Push'], ['Pull'], ['Lower Body']];
      if (days == 2) return [['Upper Body'], ['Lower Body']];
      return [['Full Body']];
    } else if (split == 'upper_lower' || split == 'ul' || split == 'ppl_ul') {
      if (days >= 2) return [['Upper Body'], ['Lower Body']];
      return [['Full Body']];
    } else if (split == 'full_body' || split == 'fb') {
      return [
        ['Full Body'],
        ['Full Body'],
        ['Full Body'],
      ];
    } else if (split == 'bro_split' || split == 'advanced') {
      if (days >= 5) {
        return [
          ['Chest'],
          ['Back'],
          ['Shoulders'],
          ['Lower Body'],
          ['Arms'],
        ];
      }
      if (days == 4) {
        return [
          ['Chest'],
          ['Back'],
          ['Shoulders & Arms'],
          ['Lower Body'],
        ];
      }
      if (days == 3) return [['Push'], ['Pull'], ['Lower Body']];
      if (days == 2) return [['Upper Body'], ['Lower Body']];
      return [['Full Body']];
    } else if (split == 'custom') {
      // Custom is handled elsewhere (player picks per day); fall back to FB.
      return [['Full Body']];
    }
    return [['Full Body']];
  }

  static String _titleForCategories(List<String> categories) {
    if (categories.contains('Push')) return 'Push Day';
    if (categories.contains('Pull')) return 'Pull Day';
    if (categories.contains('Upper Body')) return 'Upper Body';
    if (categories.contains('Lower Body')) return 'Lower Body';
    if (categories.contains('Full Body')) return 'Full Body';
    if (categories.contains('Arms')) return 'Arms Day';
    if (categories.contains('Shoulders & Arms')) return 'Shoulders & Arms';
    if (categories.contains('Legs')) return 'Leg Day';
    if (categories.isEmpty) return 'Workout';
    return '${categories.first} Day';
  }

  static String _titleForCustom(List<String> muscles) {
    if (muscles.isEmpty) return 'Workout';
    if (muscles.length == 1) return '${muscles.first} Day';
    if (muscles.length >= 6) return 'Full Body';
    return muscles.take(2).join(' & ');
  }

  static String _weekdayName(int weekday) => _weekdays[weekday - 1];

  /// Orders a muscle's exercise pool: compound movements first (good focal
  /// lifts), then the rest. Deterministic — preserves catalog order otherwise.
  static List<ExerciseModel> _pool(
    Map<String, List<ExerciseModel>> catalog,
    String muscle,
    String level, {
    int seed = 0,
    bool highAdiposity = false,
    int age = 0,
  }) {
    final allowed = _allowedExperienceLevels(level).toSet();
    final all = catalog[muscle] ?? const <ExerciseModel>[];
    final filtered = all
        .where((e) => allowed.contains(_normalizeExpLevel(e.experienceLevel)))
        .where((e) => _passesSafetyGate(e, level))
        .where((e) =>
            _passesPhysicalSafetyGate(e, highAdiposity: highAdiposity, age: age))
        .toList();
    final compound = filtered
        .where((e) => e.mechanics.toLowerCase() == 'compound')
        .toList();
    final other = filtered
        .where((e) => e.mechanics.toLowerCase() != 'compound')
        .toList();
    // Per-player variety: shuffle WITHIN the compound and isolation groups using
    // the player's seed. Compounds still come first (good focal lifts), but two
    // players get different exercise picks even at the same level.
    if (seed != 0) {
      final rnd = Random(seed ^ muscle.hashCode);
      compound.shuffle(rnd);
      other.shuffle(rnd);
    }
    return [...compound, ...other];
  }

  static String _normalizeExpLevel(String raw) {
    final r = raw.trim().toLowerCase();
    if (r.startsWith('adv')) return 'Advanced';
    if (r.startsWith('int')) return 'Intermediate';
    if (r.startsWith('beg')) return 'Beginner';
    // Unknown/None -> treat as Beginner so it's usable for everyone.
    return 'Beginner';
  }

  static double _round2_5(double w) => (w / 2.5).round() * 2.5;

  /// Progressive-overload target weight from the player's history.
  /// - No history yet  -> 0 (player establishes a baseline).
  /// - Focal/compound  -> last best + one increment (a weight to beat).
  /// - Accessory       -> last best (maintain), reps drive the overload.
  static double _progressiveWeight(
    String exerciseName,
    Map<String, double> history,
    bool focal,
  ) {
    final pr = history[exerciseName] ?? 0;
    if (pr <= 0) return 0;
    return focal ? _round2_5(pr + 2.5) : _round2_5(pr);
  }

  static RoutineExercise _toRoutineExercise(
    ExerciseModel ex,
    String level,
    String goal, {
    required bool focal,
    String? muscle,
    Map<String, double> history = const {},
  }) {
    return RoutineExercise(
      name: ex.name,
      sets: focal ? _focalSets(level) : _normalSets(level),
      reps: _reps(level, goal, focal),
      restTime: _rest(level, goal, focal),
      muscleGroup: muscle ?? ex.targetMuscleGroup,
      weight: _progressiveWeight(ex.name, history, focal),
    );
  }

  /// Builds a few level-aware routine options for a SINGLE muscle group, drawn
  /// from the Firebase catalog. Used by Quick Log so manual logging respects the
  /// player's level instead of showing the static (level-less) catalog.
  static List<RoutineModel> buildMuscleOptions(
    String muscle,
    String experienceLevel,
    Map<String, List<ExerciseModel>> catalog, {
    int variants = 3,
    int perRoutine = 5,
    TrainingProfile profile = TrainingProfile.none,
  }) {
    final level = normalizeLevel(experienceLevel);
    final goal = profile.normalizedGoal;
    final pool = _pool(catalog, muscle, level,
        seed: profile.seed,
        highAdiposity: profile.isHighAdiposity,
        age: profile.age);
    if (pool.isEmpty) return const [];

    final maxVariants = (pool.length / perRoutine).floor().clamp(1, variants);
    final out = <RoutineModel>[];
    for (int v = 0; v < maxVariants; v++) {
      final start = (v * perRoutine) % pool.length;
      final picks = <ExerciseModel>[];
      for (int k = 0; k < perRoutine && k < pool.length; k++) {
        picks.add(pool[(start + k) % pool.length]);
      }
      final exercises = <RoutineExercise>[];
      for (int k = 0; k < picks.length; k++) {
        exercises.add(_toRoutineExercise(picks[k], level, goal,
            focal: k == 0, muscle: muscle, history: profile.history));
      }
      out.add(RoutineModel(
        id: 'ql_${level}_${muscle.toLowerCase()}_$v',
        category: muscle,
        routineName: '${_levelLabel(level)} $muscle ${v + 1}',
        description: 'Level-matched $muscle routine.',
        exercises: exercises,
      ));
    }
    return out;
  }

  // Exercise types treated as "cardio/conditioning" for the Cardio category.
  static const Set<String> _cardioTypes = {
    'cardio',
    'conditioning',
    'plyometrics',
    'high intensity interval training',
    'hiit',
  };

  /// Level-filters an arbitrary exercise list (used for pseudo-categories like
  /// Glutes/Cardio that aren't their own Firebase MuscleGroup).
  static List<ExerciseModel> _filterByLevel(
    List<ExerciseModel> source,
    String level, {
    int seed = 0,
    bool compoundFirst = true,
    bool highAdiposity = false,
    int age = 0,
  }) {
    final allowed = _allowedExperienceLevels(level).toSet();
    final filtered = source
        .where((e) => allowed.contains(_normalizeExpLevel(e.experienceLevel)))
        .where((e) => _passesSafetyGate(e, level))
        .where((e) =>
            _passesPhysicalSafetyGate(e, highAdiposity: highAdiposity, age: age))
        .toList();
    if (!compoundFirst) {
      if (seed != 0) filtered.shuffle(Random(seed));
      return filtered;
    }
    final compound = filtered
        .where((e) => e.mechanics.toLowerCase() == 'compound')
        .toList();
    final other = filtered
        .where((e) => e.mechanics.toLowerCase() != 'compound')
        .toList();
    if (seed != 0) {
      final r = Random(seed);
      compound.shuffle(r);
      other.shuffle(r);
    }
    return [...compound, ...other];
  }

  /// Generic routine-option builder from a ready exercise pool.
  static List<RoutineModel> _optionsFromPool(
    List<ExerciseModel> pool, {
    required String label,
    required String level,
    required String goal,
    required String idPrefix,
    int variants = 3,
    int perRoutine = 5,
    String? repsOverride,
    int? restOverride,
    int? setsOverride,
    Map<String, double> history = const {},
  }) {
    if (pool.isEmpty) return const [];
    final maxVariants = (pool.length / perRoutine).floor().clamp(1, variants);
    final out = <RoutineModel>[];
    for (int v = 0; v < maxVariants; v++) {
      final start = (v * perRoutine) % pool.length;
      final picks = <ExerciseModel>[];
      for (int k = 0; k < perRoutine && k < pool.length; k++) {
        picks.add(pool[(start + k) % pool.length]);
      }
      final exercises = <RoutineExercise>[];
      for (int k = 0; k < picks.length; k++) {
        if (repsOverride != null) {
          exercises.add(RoutineExercise(
            name: picks[k].name,
            sets: setsOverride ?? 3,
            reps: repsOverride,
            restTime: restOverride ?? 45,
            muscleGroup: label,
            weight: 0,
          ));
        } else {
          exercises.add(_toRoutineExercise(picks[k], level, goal,
              focal: k == 0, muscle: label, history: history));
        }
      }
      out.add(RoutineModel(
        id: '${idPrefix}_$v',
        category: label,
        routineName: '${_levelLabel(level)} $label ${v + 1}',
        description: 'Personalized $label routine.',
        exercises: exercises,
      ));
    }
    return out;
  }

  /// Level + goal + seed aware options for ANY Quick-Log category, including the
  /// pseudo-categories that aren't their own Firebase MuscleGroup:
  /// Glutes (drawn from Legs), Cardio (conditioning/plyo), Full Body Fat Loss.
  /// Returns [] only when nothing suitable exists (caller may fall back).
  static List<RoutineModel> buildCategoryOptions(
    String category,
    String experienceLevel,
    Map<String, List<ExerciseModel>> catalog, {
    int variants = 3,
    int perRoutine = 5,
    TrainingProfile profile = TrainingProfile.none,
  }) {
    final level = normalizeLevel(experienceLevel);
    final goal = profile.normalizedGoal;
    final seed = profile.seed;

    switch (category) {
      case 'Glutes':
        final legs = catalog['Legs'] ?? const <ExerciseModel>[];
        final glutes = legs
            .where((e) => e.targetMuscleGroup.toLowerCase().contains('glute'))
            .toList();
        return _optionsFromPool(
          _filterByLevel(glutes, level,
              seed: seed,
              highAdiposity: profile.isHighAdiposity,
              age: profile.age),
          label: 'Glutes',
          level: level,
          goal: goal,
          idPrefix: 'ql_${level}_glutes',
          variants: variants,
          perRoutine: perRoutine,
          history: profile.history,
        );
      case 'Cardio':
        final all = <ExerciseModel>[];
        for (final list in catalog.values) {
          all.addAll(list);
        }
        final cardio = all
            .where((e) => _cardioTypes.contains(e.exerciseType.toLowerCase()))
            .toList();
        return _optionsFromPool(
          _filterByLevel(cardio, level,
              seed: seed,
              compoundFirst: false,
              highAdiposity: profile.isHighAdiposity,
              age: profile.age),
          label: 'Cardio',
          level: level,
          goal: goal,
          idPrefix: 'ql_${level}_cardio',
          variants: variants,
          perRoutine: perRoutine,
          repsOverride: '30-45 sec',
          restOverride: 30,
          setsOverride: 3,
        );
      case 'Full Body Fat Loss':
        return _fullBodyOptions(catalog, level, seed,
            variants: variants,
            history: profile.history,
            highAdiposity: profile.isHighAdiposity,
            age: profile.age);
      default:
        if (catalog.containsKey(category)) {
          return buildMuscleOptions(
            category,
            experienceLevel,
            catalog,
            variants: variants,
            perRoutine: perRoutine,
            profile: profile,
          );
        }
        return const [];
    }
  }

  /// A personalized full-body fat-loss circuit (one move per major muscle).
  static List<RoutineModel> _fullBodyOptions(
    Map<String, List<ExerciseModel>> catalog,
    String level,
    int seed, {
    int variants = 2,
    Map<String, double> history = const {},
    bool highAdiposity = false,
    int age = 0,
  }) {
    const groups = [
      'Legs',
      'Chest',
      'Back',
      'Shoulders',
      'Biceps',
      'Triceps',
      'Abs',
    ];
    final out = <RoutineModel>[];
    for (int v = 0; v < variants; v++) {
      final used = <String>{};
      final exercises = <RoutineExercise>[];
      for (final mg in groups) {
        final pool = _pool(catalog, mg, level,
            seed: seed == 0 ? 0 : seed + v,
            highAdiposity: highAdiposity,
            age: age);
        if (pool.isEmpty) continue;
        final pick = pool.firstWhere(
          (e) => !used.contains(e.name),
          orElse: () => pool.first,
        );
        used.add(pick.name);
        // Fat-loss style reps/rest regardless of the player's stated goal.
        exercises.add(_toRoutineExercise(pick, level, 'fat_loss',
            focal: false, muscle: mg, history: history));
      }
      if (exercises.isEmpty) continue;
      out.add(RoutineModel(
        id: 'ql_${level}_fullbody_$v',
        category: 'Full Body Fat Loss',
        routineName: '${_levelLabel(level)} Full Body ${v + 1}',
        description: 'Full-body fat-loss circuit.',
        exercises: exercises,
      ));
    }
    return out;
  }

  /// Default muscles for a custom day the player left empty.
  static const List<String> _customFallbackMuscles = [
    'Chest',
    'Back',
    'Legs',
    'Shoulders',
    'Biceps',
    'Triceps',
  ];

  /// Generates the full plan.
  ///
  /// For the "custom" split, [customDayMuscles] maps a weekday code (MON..SUN)
  /// to the muscle groups the player chose for that day; those drive each day
  /// directly (level-filtered) instead of the preset split mapping.
  static WorkoutPlanResult generate({
    required String experienceLevel,
    required int daysPerWeek,
    required String splitType,
    required List<String> trainingDays,
    required Map<String, List<ExerciseModel>> exerciseCatalog,
    required DateTime startDate,
    Map<String, String> swaps = const {},
    Map<String, List<String>> customDayMuscles = const {},
    TrainingProfile profile = TrainingProfile.none,
  }) {
    if (exerciseCatalog.isEmpty || trainingDays.isEmpty) {
      return WorkoutPlanResult.empty;
    }

    final level = normalizeLevel(experienceLevel);
    final goal = profile.normalizedGoal;
    final seed = profile.seed;
    final history = profile.history;
    final isCustom = splitType == 'custom';

    // Build the ordered category list, looped/trimmed to the training-day count.
    var mapping = _categoryMapping(daysPerWeek, splitType);
    while (mapping.length < trainingDays.length) {
      mapping = [...mapping, ..._categoryMapping(daysPerWeek, splitType)];
    }
    mapping = mapping.take(trainingDays.length).toList();

    final target = _dayTarget(level);
    final cap = _perMuscleCap(level);
    final used = <String>{}; // exercise names already placed this week (dedupe)
    final coveredMuscles = <String>{};
    final routines = <String, RoutineModel>{};

    // Holds, per generated routine id, the mutable exercise list (so the
    // gap-fill pass can append to the right day later).
    final routineExercises = <String, List<RoutineExercise>>{};
    final List<WorkoutDay> plan = [];
    final List<String> trainingRoutineIds = []; // for round-robin gap-fill

    int dayCount = 0;
    for (int i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final dayName = _weekdayName(date.weekday);

      if (trainingDays.contains(dayName) && dayCount < mapping.length) {
        // Resolve this day's ordered muscle list (no duplicates) + display
        // categories. Custom days come straight from the player's choices.
        final List<String> cats;
        final muscles = <String>[];
        if (isCustom) {
          final chosen = customDayMuscles[dayName];
          final dayMuscles = (chosen == null || chosen.isEmpty)
              ? _customFallbackMuscles
              : chosen;
          for (final mg in dayMuscles) {
            if (!muscles.contains(mg)) muscles.add(mg);
          }
          cats = List<String>.from(muscles);
        } else {
          cats = mapping[dayCount];
          for (final c in cats) {
            for (final mg in (_categoryMuscles[c] ?? const [])) {
              if (!muscles.contains(mg)) muscles.add(mg);
            }
          }
        }
        final title = isCustom
            ? _titleForCustom(muscles)
            : _titleForCategories(cats);

        final nMuscles = muscles.isEmpty ? 1 : muscles.length;
        final base = (target ~/ nMuscles).clamp(1, cap);
        final remainder = (target - base * nMuscles).clamp(0, nMuscles);

        final exercises = <RoutineExercise>[];
        for (int m = 0; m < muscles.length; m++) {
          final mg = muscles[m];
          final count = (base + (m < remainder ? 1 : 0)).clamp(1, cap);
          final pool = _pool(exerciseCatalog, mg, level,
              seed: seed,
              highAdiposity: profile.isHighAdiposity,
              age: profile.age);
          if (pool.isEmpty) continue;

          // Prefer not-yet-used exercises; fall back if a muscle is thin.
          final fresh = pool.where((e) => !used.contains(e.name)).toList();
          final chosen = <ExerciseModel>[];
          chosen.addAll(fresh.take(count));
          if (chosen.length < count) {
            for (final e in pool) {
              if (chosen.length >= count) break;
              if (!chosen.contains(e)) chosen.add(e);
            }
          }
          for (int k = 0; k < chosen.length; k++) {
            used.add(chosen[k].name);
            exercises.add(
              _toRoutineExercise(chosen[k], level, goal,
                  focal: k == 0, muscle: mg, history: history),
            );
          }
          if (chosen.isNotEmpty) coveredMuscles.add(mg);
        }

        final routineId = 'gen_${level}_${dayCount}_${dayName.toLowerCase()}';
        routineExercises[routineId] = exercises;
        trainingRoutineIds.add(routineId);

        plan.add(WorkoutDay(
          dayName: dayName,
          date: date.day.toString(),
          fullDate: date.toIso8601String().split('T')[0],
          title: title,
          categories: cats,
          assignedRoutineId: routineId,
          assignedRoutineName: title,
        ));
        dayCount++;
      } else {
        plan.add(WorkoutDay(
          dayName: dayName,
          date: date.day.toString(),
          fullDate: date.toIso8601String().split('T')[0],
          title: 'Rest Day',
          categories: const [],
          isRest: true,
        ));
      }
    }

    // ── Gap-fill: guarantee every muscle group is trained at least once. ──
    // Skipped for custom: there we respect exactly the muscles the player chose.
    if (!isCustom && trainingRoutineIds.isNotEmpty) {
      int rr = 0;
      for (final mg in allMuscles) {
        if (coveredMuscles.contains(mg)) continue;
        final pool = _pool(exerciseCatalog, mg, level,
            seed: seed,
            highAdiposity: profile.isHighAdiposity,
            age: profile.age);
        if (pool.isEmpty) continue;
        final pick = pool.firstWhere(
          (e) => !used.contains(e.name),
          orElse: () => pool.first,
        );
        used.add(pick.name);
        final id = trainingRoutineIds[rr % trainingRoutineIds.length];
        routineExercises[id]!.add(_toRoutineExercise(pick, level, goal,
            focal: false, muscle: mg, history: history));
        coveredMuscles.add(mg);
        rr++;
      }
    }

    // Materialize routines now that exercise lists are final.
    for (int d = 0; d < plan.length; d++) {
      final wd = plan[d];
      final id = wd.assignedRoutineId;
      if (id == null) continue;
      routines[id] = RoutineModel(
        id: id,
        category: wd.categories.isNotEmpty ? wd.categories.first : 'Full Body',
        routineName: wd.title,
        description:
            'Auto-generated for ${_levelLabel(level)} • ${wd.categories.join(' · ')}',
        exercises: routineExercises[id] ?? const [],
      );
    }

    // ── Apply day swaps (same semantics as the old generator). ──
    if (swaps.isNotEmpty) {
      final swapped = List<WorkoutDay>.from(plan);
      for (int i = 0; i < plan.length; i++) {
        final dateKey =
            startDate.add(Duration(days: i)).toIso8601String().split('T')[0];
        final targetDateKey = swaps[dateKey];
        if (targetDateKey == null) continue;
        int targetIndex = -1;
        for (int j = 0; j < plan.length; j++) {
          if (startDate.add(Duration(days: j)).toIso8601String().split('T')[0] ==
              targetDateKey) {
            targetIndex = j;
            break;
          }
        }
        if (targetIndex != -1 && targetIndex > i) {
          final a = swapped[i];
          final b = swapped[targetIndex];
          swapped[i] = WorkoutDay(
            dayName: a.dayName,
            date: a.date,
            fullDate: a.fullDate,
            title: b.title,
            categories: b.categories,
            assignedRoutineId: b.assignedRoutineId,
            assignedRoutineName: b.assignedRoutineName,
            isRest: b.isRest,
          );
          swapped[targetIndex] = WorkoutDay(
            dayName: b.dayName,
            date: b.date,
            fullDate: b.fullDate,
            title: a.title,
            categories: a.categories,
            assignedRoutineId: a.assignedRoutineId,
            assignedRoutineName: a.assignedRoutineName,
            isRest: a.isRest,
          );
        }
      }
      return WorkoutPlanResult(days: swapped, routines: routines);
    }

    return WorkoutPlanResult(days: plan, routines: routines);
  }

  static String _levelLabel(String level) {
    switch (normalizeLevel(level)) {
      case 'advanced':
        return 'Advanced';
      case 'intermediate':
        return 'Intermediate';
      default:
        return 'Beginner';
    }
  }
}

/// Firebase exercise database grouped by MuscleGroup, ready for the engine.
final firebaseExerciseCatalogProvider =
    FutureProvider<Map<String, List<ExerciseModel>>>((ref) async {
  final groups = await ref.watch(allExercisesProvider.future);
  final map = <String, List<ExerciseModel>>{};
  for (final g in groups) {
    map.putIfAbsent(g.muscleGroup, () => []).addAll(g.exercises);
  }
  return map;
});
