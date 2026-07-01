// lib/src/core/utils/otp_rate_limiter.dart
//
// Client-side guard against spamming OTP resend requests (max 3 sends per
// rolling 10-minute window, per phone number).
//
// This is a soft, UX-level limit only — it lives in SharedPreferences and can
// be cleared by reinstalling the app. The real hard security boundary is
// Firebase Phone Auth's own per-number SMS quota on the backend, which this
// cannot bypass or weaken either way. The purpose here is purely to show a
// clear, friendly message before the user ever hits Firebase's own generic
// "too-many-requests" error, and to discourage accidental button-mashing.

import '../../../main.dart' as app_main;

abstract final class OtpRateLimiter {
  static const maxSendsPerWindow = 3;
  static const windowDuration = Duration(minutes: 10);

  /// Returns true if another OTP send is allowed right now for [phone].
  /// Call this BEFORE triggering verifyPhoneNumber.
  static bool canSend(String phone) {
    final prefs = app_main.globalSharedPrefs;
    final key = _key(phone);
    final windowStartMs = prefs.getInt('${key}_start');
    if (windowStartMs == null) return true;

    final elapsedMs = DateTime.now().millisecondsSinceEpoch - windowStartMs;
    if (elapsedMs > windowDuration.inMilliseconds) return true; // window expired

    final count = prefs.getInt('${key}_count') ?? 0;
    return count < maxSendsPerWindow;
  }

  /// Call this right after Firebase confirms the code was actually sent
  /// (i.e. inside the `codeSent` callback), to record it against the
  /// per-phone rolling window.
  static void recordSend(String phone) {
    final prefs = app_main.globalSharedPrefs;
    final key = _key(phone);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final windowStartMs = prefs.getInt('${key}_start');

    if (windowStartMs == null ||
        nowMs - windowStartMs > windowDuration.inMilliseconds) {
      prefs.setInt('${key}_start', nowMs);
      prefs.setInt('${key}_count', 1);
    } else {
      prefs.setInt('${key}_count', (prefs.getInt('${key}_count') ?? 0) + 1);
    }
  }

  /// Seconds remaining until the current rate-limit window resets (0 if the
  /// user isn't currently capped).
  static int secondsUntilReset(String phone) {
    final prefs = app_main.globalSharedPrefs;
    final key = _key(phone);
    final windowStartMs = prefs.getInt('${key}_start');
    if (windowStartMs == null) return 0;

    final elapsedMs = DateTime.now().millisecondsSinceEpoch - windowStartMs;
    final remainingMs = windowDuration.inMilliseconds - elapsedMs;
    return remainingMs > 0 ? (remainingMs / 1000).ceil() : 0;
  }

  static String _key(String phone) =>
      'otp_rate_${phone.replaceAll(RegExp(r'[^0-9+]'), '')}';
}
