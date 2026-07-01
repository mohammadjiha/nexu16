import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../auth/data/auth_repository.dart';
import '../../providers/coach_plan_provider.dart';

/// Lets the player choose / switch which plan they follow: their coach's plan
/// or their own. Shows a first-time chooser, then a compact switcher. Renders
/// nothing if the coach hasn't assigned a plan.
class PlanSourceBanner extends ConsumerWidget {
  const PlanSourceBanner({super.key});

  bool _isAr(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  Future<void> _choose(WidgetRef ref, String source) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    await ref
        .read(coachPlanRepositoryProvider)
        .setPlanSource(uid: uid, source: source);

    if (source == 'coach') {
      // Notify the coach that the player is following their plan.
      final coachId = ref.read(coachPlanProvider).asData?.value.coachId;
      if (coachId != null && coachId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(coachId)
              .collection('notifications')
              .add({
            'title': 'Coach Plan',
            'body': 'A player is now following your training plan.',
            'type': 'coach_plan_followed',
            'route': '/coach_monitoring',
            'read': false,
            'senderId': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachPlan = ref.watch(coachPlanProvider).asData?.value;
    final prefs = ref.watch(planSourceProvider).asData?.value ?? const PlanPrefs();
    final isAr = _isAr(context);

    // No coach plan → nothing to choose; player stays on their own plan.
    if (coachPlan == null || coachPlan.isEmpty) return const SizedBox.shrink();

    // First-time chooser.
    if (!prefs.chosen) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 4.4.w, vertical: 1.h),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(4.w),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAr ? 'مدرّبك جهّز لك خطة! 🧑‍🏫' : 'Your coach set you a plan! 🧑‍🏫',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 0.6.h),
            Text(
              isAr ? 'أي خطة بدك تتبع؟' : 'Which plan do you want to follow?',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: 1.6.h),
            Row(
              children: [
                Expanded(
                  child: _choiceButton(
                    label: isAr ? 'خطة المدرّب' : "Coach's plan",
                    filled: true,
                    onTap: () => _choose(ref, 'coach'),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: _choiceButton(
                    label: isAr ? 'خطتي' : 'My plan',
                    filled: false,
                    onTap: () => _choose(ref, 'self'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Already chosen → compact switcher.
    final following = prefs.isCoach
        ? (isAr ? 'خطة المدرّب 🧑‍🏫' : "Coach's plan 🧑‍🏫")
        : (isAr ? 'خطتي 🏋️' : 'My plan 🏋️');
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.4.w, vertical: 0.6.h),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.4.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(3.5.w),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${isAr ? 'تتبع' : 'Following'}: $following',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _choose(ref, prefs.isCoach ? 'self' : 'coach'),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(2.5.w),
              ),
              child: Text(
                isAr
                    ? (prefs.isCoach ? 'خطتي' : 'خطة المدرّب')
                    : (prefs.isCoach ? 'My plan' : "Coach's"),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceButton({
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 1.4.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(3.w),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: filled ? const Color(0xFF1C1C1E) : Colors.white,
          ),
        ),
      ),
    );
  }
}
