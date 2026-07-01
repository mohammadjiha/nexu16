import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Single meal log ─────────────────────────────────────────────────────────
class MealLog {
  final String mealName;
  final bool completed;
  final DateTime? completedAt;

  const MealLog({
    required this.mealName,
    required this.completed,
    this.completedAt,
  });

  factory MealLog.fromMap(Map<String, dynamic> m) => MealLog(
        mealName: m['mealName'] as String? ?? '',
        completed: m['completed'] as bool? ?? false,
        completedAt: (m['completedAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'mealName': mealName,
        'completed': completed,
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      };

  MealLog copyWith({bool? completed, DateTime? completedAt}) => MealLog(
        mealName: mealName,
        completed: completed ?? this.completed,
        completedAt: completedAt ?? this.completedAt,
      );
}

// ─── Daily tracking document ──────────────────────────────────────────────────
class DailyMealTracking {
  final String date; // "2026-06-25"
  final List<MealLog> meals;
  final DateTime? updatedAt;

  const DailyMealTracking({
    required this.date,
    required this.meals,
    this.updatedAt,
  });

  int get completedCount => meals.where((m) => m.completed).length;
  int get totalCount => meals.length;
  double get complianceRate =>
      totalCount > 0 ? completedCount / totalCount : 0.0;

  factory DailyMealTracking.empty(String date) =>
      DailyMealTracking(date: date, meals: []);

  factory DailyMealTracking.fromMap(String date, Map<String, dynamic> m) {
    final raw = m['coachMealTracking'];
    List<MealLog> meals = [];
    if (raw is List) {
      meals = raw
          .map((e) => MealLog.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return DailyMealTracking(
      date: date,
      meals: meals,
      updatedAt: (m['trackingUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'coachMealTracking': meals.map((m) => m.toMap()).toList(),
        'trackingUpdatedAt': FieldValue.serverTimestamp(),
      };
}
