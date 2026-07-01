import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../nutrition/data/coach_nutrition_repository.dart';
import '../../../nutrition/data/daily_meal_tracking_repository.dart';
import '../../../nutrition/domain/models/coach_nutrition_plan.dart';
import '../../../nutrition/domain/models/daily_meal_tracking.dart';
import '../../../auth/data/auth_repository.dart';

class MealTrackingScreen extends ConsumerWidget {
  const MealTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).asData?.value?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final planAsync = ref.watch(coachNutritionPlanProvider(uid));
    final trackingAsync = ref.watch(todayMealTrackingProvider(uid));

    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: const Color(0x1A000000),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20.sp, color: const Color(0xFF1C1C1E)),
        ),
        title: Column(
          children: [
            Text(
              "Today's Meals",
              style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E)),
            ),
            Text(
              today,
              style:
                  TextStyle(fontSize: 11.sp, color: const Color(0xFF8E8E93)),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('error_with_detail'.trP(context, {'e': e}))),
        data: (plan) {
          if (plan == null || plan.meals.isEmpty) {
            return Center(
              child: Text(
                'no_coach_plan_yet'.tr(context),
                style: TextStyle(fontSize: 15.sp, color: const Color(0xFF8E8E93)),
              ),
            );
          }

          final tracking = trackingAsync.asData?.value;
          final mealNames = plan.meals.map((m) => m.name).toList();
          final done = tracking == null
              ? 0
              : tracking.meals.where((m) => m.completed).length;
          final total = plan.meals.length;

          return Column(
            children: [
              // ── Progress bar ────────────────────────────────────────────
              Container(
                margin: EdgeInsets.all(4.w),
                padding:
                    EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4.w),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          done == total && total > 0
                              ? '🎉 All meals done!'
                              : '$done of $total meals completed',
                          style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: done == total && total > 0
                                  ? const Color(0xFF34C759)
                                  : const Color(0xFF1C1C1E)),
                        ),
                        Text(
                          '${(done / total * 100).round()}%',
                          style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF34C759)),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.2.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: total > 0 ? done / total : 0,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFE5E5EA),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF34C759)),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Meals list ──────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  padding:
                      EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  itemCount: plan.meals.length,
                  separatorBuilder: (_, __) => SizedBox(height: 1.5.h),
                  itemBuilder: (ctx, i) {
                    final meal = plan.meals[i];
                    final isCompleted = tracking != null &&
                        i < tracking.meals.length &&
                        tracking.meals[i].completed;

                    return _MealTrackCard(
                      meal: meal,
                      mealIdx: i,
                      playerUid: uid,
                      mealNames: mealNames,
                      isCompleted: isCompleted,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Single meal tracking card ────────────────────────────────────────────────
class _MealTrackCard extends ConsumerWidget {
  final CoachMeal meal;
  final int mealIdx;
  final String playerUid;
  final List<String> mealNames;
  final bool isCompleted;

  const _MealTrackCard({
    required this.meal,
    required this.mealIdx,
    required this.playerUid,
    required this.mealNames,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFEFFAF3) : Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(
          color:
              isCompleted ? const Color(0xFF34C759) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // ── Meal header ──────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFD4F5E2)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  alignment: Alignment.center,
                  child: Text(meal.icon,
                      style: TextStyle(fontSize: 22.sp)),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.name,
                        style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: isCompleted
                                ? const Color(0xFF1A7A30)
                                : const Color(0xFF1C1C1E)),
                      ),
                      if (meal.time.isNotEmpty) ...[
                        SizedBox(height: 0.3.h),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 13.sp,
                                color: const Color(0xFF8E8E93)),
                            SizedBox(width: 1.w),
                            Text(meal.time,
                                style: TextStyle(
                                    fontSize: 13.sp,
                                    color: const Color(0xFF8E8E93))),
                          ],
                        ),
                      ],
                      SizedBox(height: 0.3.h),
                      Text(
                        '${meal.totalCalories} kcal · P:${meal.totalProtein.toStringAsFixed(0)}g · C:${meal.totalCarbs.toStringAsFixed(0)}g · F:${meal.totalFat.toStringAsFixed(0)}g',
                        style: TextStyle(
                            fontSize: 13.sp,
                            color: const Color(0xFF8E8E93)),
                      ),
                    ],
                  ),
                ),
                // ── Check button ───────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    ref
                        .read(dailyMealTrackingRepositoryProvider)
                        .toggleMeal(
                          playerUid: playerUid,
                          mealIdx: mealIdx,
                          mealNames: mealNames,
                        );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 14.w,
                    height: 14.w,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF34C759)
                          : Colors.transparent,
                      border: Border.all(
                        color: isCompleted
                            ? const Color(0xFF34C759)
                            : const Color(0xFFD1D1D6),
                        width: 2,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: isCompleted
                        ? Icon(Icons.check_rounded,
                            color: Colors.white, size: 18.sp)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          // ── Foods ────────────────────────────────────────────────────
          if (meal.foods.isNotEmpty)
            Container(
              margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFFD4F5E2).withValues(alpha: 0.4)
                    : const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: Column(
                children: meal.foods
                    .map((f) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 0.5.h),
                          child: Row(
                            children: [
                              Text(f.emoji,
                                  style: TextStyle(fontSize: 18.sp)),
                              SizedBox(width: 2.w),
                              Expanded(
                                child: Text(
                                  f.amount.isNotEmpty
                                      ? '${f.name} — ${f.amount}'
                                      : f.name,
                                  style: TextStyle(
                                      fontSize: 14.sp,
                                      color: const Color(0xFF3A3A3C)),
                                ),
                              ),
                              Text(
                                '${f.calories} kcal',
                                style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF8E8E93)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
