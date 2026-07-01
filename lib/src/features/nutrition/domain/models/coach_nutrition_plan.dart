import 'package:cloud_firestore/cloud_firestore.dart';

class CoachFoodItem {
  final String emoji;
  final String name;
  final String amount;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  const CoachFoodItem({
    required this.emoji,
    required this.name,
    required this.amount,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toMap() => {
        'emoji': emoji,
        'name': name,
        'amount': amount,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory CoachFoodItem.fromMap(Map<String, dynamic> m) => CoachFoodItem(
        emoji: m['emoji'] as String? ?? '🍽️',
        name: m['name'] as String? ?? '',
        amount: m['amount'] as String? ?? '',
        calories: (m['calories'] as num?)?.toInt() ?? 0,
        protein: (m['protein'] as num?)?.toDouble() ?? 0,
        carbs: (m['carbs'] as num?)?.toDouble() ?? 0,
        fat: (m['fat'] as num?)?.toDouble() ?? 0,
      );

  CoachFoodItem copyWith({
    String? emoji,
    String? name,
    String? amount,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) =>
      CoachFoodItem(
        emoji: emoji ?? this.emoji,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
      );
}

class CoachMeal {
  final String icon;
  final String name;
  final String time;
  final List<CoachFoodItem> foods;

  const CoachMeal({
    required this.icon,
    required this.name,
    required this.time,
    required this.foods,
  });

  int get totalCalories => foods.fold(0, (s, f) => s + f.calories);
  double get totalProtein => foods.fold(0.0, (s, f) => s + f.protein);
  double get totalCarbs => foods.fold(0.0, (s, f) => s + f.carbs);
  double get totalFat => foods.fold(0.0, (s, f) => s + f.fat);

  Map<String, dynamic> toMap() => {
        'icon': icon,
        'name': name,
        'time': time,
        'foods': foods.map((f) => f.toMap()).toList(),
      };

  factory CoachMeal.fromMap(Map<String, dynamic> m) => CoachMeal(
        icon: m['icon'] as String? ?? '🍽️',
        name: m['name'] as String? ?? '',
        time: m['time'] as String? ?? '',
        foods: ((m['foods'] as List<dynamic>?) ?? [])
            .map((f) => CoachFoodItem.fromMap(f as Map<String, dynamic>))
            .toList(),
      );

  CoachMeal copyWith({
    String? icon,
    String? name,
    String? time,
    List<CoachFoodItem>? foods,
  }) =>
      CoachMeal(
        icon: icon ?? this.icon,
        name: name ?? this.name,
        time: time ?? this.time,
        foods: foods ?? this.foods,
      );
}

class CoachNutritionPlan {
  final String coachUid;
  final String coachName;
  final String coachDesc;
  final String coachNote;
  final int totalCalories;
  final double protein;
  final double carbs;
  final double fat;
  final List<CoachMeal> meals;
  final DateTime updatedAt;

  const CoachNutritionPlan({
    required this.coachUid,
    required this.coachName,
    required this.coachDesc,
    required this.coachNote,
    required this.totalCalories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.meals,
    required this.updatedAt,
  });

  int get computedCalories => meals.fold(0, (s, m) => s + m.totalCalories);
  double get computedProtein => meals.fold(0.0, (s, m) => s + m.totalProtein);
  double get computedCarbs => meals.fold(0.0, (s, m) => s + m.totalCarbs);
  double get computedFat => meals.fold(0.0, (s, m) => s + m.totalFat);

  Map<String, dynamic> toMap() => {
        'coachUid': coachUid,
        'coachName': coachName,
        'coachDesc': coachDesc,
        'coachNote': coachNote,
        'totalCalories': computedCalories,
        'protein': computedProtein,
        'carbs': computedCarbs,
        'fat': computedFat,
        'meals': meals.map((m) => m.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory CoachNutritionPlan.fromMap(Map<String, dynamic> m) {
    final ts = m['updatedAt'];
    DateTime updatedAt = DateTime.now();
    if (ts is Timestamp) updatedAt = ts.toDate();

    return CoachNutritionPlan(
      coachUid: m['coachUid'] as String? ?? '',
      coachName: m['coachName'] as String? ?? '',
      coachDesc: m['coachDesc'] as String? ?? '',
      coachNote: m['coachNote'] as String? ?? '',
      totalCalories: (m['totalCalories'] as num?)?.toInt() ?? 0,
      protein: (m['protein'] as num?)?.toDouble() ?? 0,
      carbs: (m['carbs'] as num?)?.toDouble() ?? 0,
      fat: (m['fat'] as num?)?.toDouble() ?? 0,
      meals: ((m['meals'] as List<dynamic>?) ?? [])
          .map((x) => CoachMeal.fromMap(x as Map<String, dynamic>))
          .toList(),
      updatedAt: updatedAt,
    );
  }
}
