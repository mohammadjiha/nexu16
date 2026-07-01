import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../nutrition/domain/models/daily_meal_tracking.dart';

import '../../../nutrition/data/coach_nutrition_repository.dart';
import '../../../nutrition/data/daily_meal_tracking_repository.dart';
import '../../../nutrition/domain/models/coach_nutrition_plan.dart';
import '../../../user/models/user_model.dart';
import 'coach_set_nutrition_screen.dart';

class CoachPlayerNutritionDetailScreen extends ConsumerWidget {
  final UserModel player;
  const CoachPlayerNutritionDetailScreen({super.key, required this.player});

  String get _playerName =>
      '${player.firstName ?? ''} ${player.lastName ?? ''}'.trim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(coachNutritionPlanProvider(player.uid));
    final trackingAsync = ref.watch(last7DaysTrackingProvider(player.uid));

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
            Text('nutrition_plan_header'.tr(context),
                style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E))),
            Text(_playerName,
                style: TextStyle(
                    fontSize: 12.sp, color: const Color(0xFF8E8E93))),
          ],
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CoachSetNutritionScreen(player: player)),
            ),
            child: Container(
              margin: EdgeInsets.only(right: 4.w),
              padding:
                  EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.8.h),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(6.w),
              ),
              child: Text('edit_label'.tr(context),
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('error_with_detail'.trP(context, {'e': e}))),
        data: (plan) => SingleChildScrollView(
          padding: EdgeInsets.all(4.w),
          child: Column(
            children: [
              if (plan == null)
                _buildNoPlan(context)
              else ...[
                _buildMacroCard(context, plan),
                SizedBox(height: 2.h),
                _buildComplianceCard(context, trackingAsync),
                SizedBox(height: 2.h),
                _buildMealsList(context, plan),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── No plan yet ────────────────────────────────────────────────────────────
  Widget _buildNoPlan(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 20.h),
        child: Column(
          children: [
            Text('🍽️', style: TextStyle(fontSize: 50.sp)),
            SizedBox(height: 2.h),
            Text('no_plan_set_yet'.tr(context),
                style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E))),
            SizedBox(height: 1.h),
            Text('press_edit_create_plan'.tr(context),
                style: TextStyle(
                    fontSize: 13.sp, color: const Color(0xFF8E8E93))),
          ],
        ),
      ),
    );
  }

  // ── Macro summary card ─────────────────────────────────────────────────────
  Widget _buildMacroCard(BuildContext context, CoachNutritionPlan plan) {
    return Container(
      padding: EdgeInsets.all(4.5.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('daily_target_label'.tr(context),
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 0.7)),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _macroStat('${plan.computedCalories}', 'kcal_upper'.tr(context), Colors.white),
              _macroStat('${plan.computedProtein.toStringAsFixed(0)}g',
                  'protein_upper'.tr(context), const Color(0xFF007AFF)),
              _macroStat('${plan.computedCarbs.toStringAsFixed(0)}g',
                  'carbs_upper'.tr(context), const Color(0xFFFF9500)),
              _macroStat('${plan.computedFat.toStringAsFixed(0)}g', 'fat_upper'.tr(context),
                  const Color(0xFFFF3B30)),
            ],
          ),
          if (plan.coachNote.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: Text(
                '"${plan.coachNote}"',
                style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                    height: 1.5),
              ),
            ),
          ],
          SizedBox(height: 1.5.h),
          Text(
            'updated_on_date'.trP(context, {'date': DateFormat('MMM d').format(plan.updatedAt)}),
            style: TextStyle(
                fontSize: 10.sp,
                color: Colors.white.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }

  Widget _macroStat(String val, String lbl, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(val,
              style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(lbl,
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.4))),
        ],
      );

  // ── 7-day compliance ───────────────────────────────────────────────────────
  Widget _buildComplianceCard(BuildContext context, AsyncValue<List<DailyMealTracking>> trackingAsync) {
    return Container(
      padding: EdgeInsets.all(4.w),
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
              Text('player_compliance_label'.tr(context),
                  style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E))),
              Text('last_7_days_label'.tr(context),
                  style: TextStyle(
                      fontSize: 13.sp, color: const Color(0xFF8E8E93))),
            ],
          ),
          SizedBox(height: 2.h),
          trackingAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
            data: (days) {
              final hasDays = days.any((d) => d.totalCount > 0);
              if (!hasDays) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    child: Text('no_tracking_data_yet'.tr(context),
                        style: TextStyle(
                            fontSize: 13.sp,
                            color: const Color(0xFF8E8E93))),
                  ),
                );
              }

              // Overall rate this week
              var totalDone = 0;
              var totalPossible = 0;
              for (final d in days) { totalDone += d.completedCount; totalPossible += d.totalCount; }
              final overallRate =
                  totalPossible > 0 ? totalDone / totalPossible : 0.0;

              return Column(
                children: [
                  // Overall % pill
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 3.w, vertical: 0.5.h),
                        decoration: BoxDecoration(
                          color: _complianceColor(overallRate)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4.w),
                        ),
                        child: Text(
                          'pct_this_week'.trP(context, {'pct': (overallRate * 100).round()}),
                          style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: _complianceColor(overallRate)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  // Bar chart — oldest on left
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: days.reversed.map((d) {
                      final label = _shortDay(context, d.date);
                      final rate = d.complianceRate;
                      final color = d.totalCount == 0
                          ? const Color(0xFFE5E5EA)
                          : _complianceColor(rate);

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 0.5.w),
                          child: Column(
                            children: [
                              if (d.totalCount > 0)
                                Text(
                                  '${d.completedCount}/${d.totalCount}',
                                  style: TextStyle(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w700,
                                      color: color),
                                ),
                              SizedBox(height: 0.5.h),
                              Container(
                                height: 8.h,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F7),
                                  borderRadius: BorderRadius.circular(2.w),
                                ),
                                alignment: Alignment.bottomCenter,
                                clipBehavior: Clip.hardEdge,
                                child: FractionallySizedBox(
                                  heightFactor: d.totalCount == 0
                                      ? 0.04
                                      : rate.clamp(0.04, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(2.w),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 0.5.h),
                              Text(label,
                                  style: TextStyle(
                                      fontSize: 11.sp,
                                      color: const Color(0xFF8E8E93),
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _complianceColor(double rate) => rate >= 0.75
      ? const Color(0xFF34C759)
      : rate >= 0.4
          ? const Color(0xFFFF9500)
          : const Color(0xFFFF3B30);

  String _shortDay(BuildContext context, String dateStr) {
    try {
      final p = dateStr.split('-');
      final d =
          DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      final now = DateTime.now();
      if (d.day == now.day && d.month == now.month) return 'today'.tr(context);
      return DateFormat('EEE').format(d);
    } catch (_) {
      return '';
    }
  }

  // ── Meals list ─────────────────────────────────────────────────────────────
  Widget _buildMealsList(BuildContext context, CoachNutritionPlan plan) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.5.h, 4.w, 1.h),
            child: Text('meal_plan_title'.tr(context),
                style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E))),
          ),
          ...plan.meals.asMap().entries.map((e) {
            final meal = e.value;
            final isLast = e.key == plan.meals.length - 1;
            return Container(
              decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: Color(0xFFF5F5F7), width: 0.5))),
              padding: EdgeInsets.fromLTRB(
                  4.w, 2.h, 4.w, isLast ? 2.5.h : 2.h),
              child: Row(
                children: [
                  Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(2.5.w)),
                    alignment: Alignment.center,
                    child: Text(meal.icon,
                        style: TextStyle(fontSize: 18.sp)),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal.time.isNotEmpty
                              ? '${meal.name} — ${meal.time}'
                              : meal.name,
                          style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1C1C1E)),
                        ),
                        SizedBox(height: 0.2.h),
                        Text(
                          'kcal_items_count'.trP(context, {'kcal': meal.totalCalories, 'count': meal.foods.length}),
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF8E8E93)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
