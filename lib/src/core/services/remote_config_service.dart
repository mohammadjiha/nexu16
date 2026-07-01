import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final remoteConfigProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService();
});

class RemoteConfigService {
  // Lazily initialized — not called until init() runs
  FirebaseRemoteConfig? _remoteConfig;

  /// Always returns a usable instance: falls back to the Firebase singleton even
  /// if [init] was never called on THIS object, so reads never silently no-op.
  FirebaseRemoteConfig get _rc =>
      _remoteConfig ??= FirebaseRemoteConfig.instance;

  Future<void> init() async {
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode
              ? const Duration()
              : const Duration(hours: 1),
        ),
      );

      await _remoteConfig!.setDefaults({
        'onboarding_title_1': 'Enter your Gym Code',
        'onboarding_subtitle_1':
            'If your gym uses NEXUS, enter the code provided by your gym manager.',
        'onboarding_title_2': "What's your role?",
        'onboarding_subtitle_2':
            'This helps us personalize your NEXUS experience from day one.',
        'role_player_title': 'Player / Member',
        'role_player_subtitle': 'I want to track my workouts and nutrition',
        'role_coach_title': 'Coach / Personal Trainer',
        'role_coach_subtitle': 'I want to manage my clients and plans',
        'role_admin_title': 'Gym Owner / Admin',
        'role_admin_subtitle': 'I want to manage my gym facility',

        // ── Forced app update ────────────────────────────────────────────────
        // Set 'min_supported_version' in the Firebase Console (Remote Config)
        // to the lowest app version (e.g. "1.2.0") still allowed to run. Any
        // installed version below it is blocked with a mandatory update screen.
        // Leave at '0.0.0' to disable forced updates entirely.
        'min_supported_version': '0.0.0',
        'update_url_android': '',
        'update_url_ios': '',
      });

      await _remoteConfig!.fetchAndActivate();

      debugPrint('Remote Config initialized successfully');
    } catch (e) {
      debugPrint('Remote Config init failed: $e');
      // We do NOT set _remoteConfig to null here, so the app can still read
      // locally cached values from previous successful fetches, or default values.
    }
  }

  // Safe getters — read from the live singleton; never silently no-op.
  String getString(String key) {
    try {
      return _rc.getString(key);
    } catch (_) {
      return '';
    }
  }

  bool getBool(String key) {
    try {
      return _rc.getBool(key);
    } catch (_) {
      return false;
    }
  }

  double getDouble(String key) {
    try {
      return _rc.getDouble(key);
    } catch (_) {
      return 0.0;
    }
  }

  int getInt(String key) {
    try {
      return _rc.getInt(key);
    } catch (_) {
      return 0;
    }
  }

  /// Forces a fresh fetch from the server (bypassing the cache/minimum interval)
  /// and returns the value. Use this for critical values (like API keys) so a
  /// failed/stale startup fetch never permanently breaks a feature.
  Future<String> getStringForceFetch(String key) async {
    try {
      final rc = _rc;
      // Temporarily allow an immediate fetch regardless of the interval.
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 12),
          minimumFetchInterval: Duration.zero,
        ),
      );
      await rc.fetchAndActivate();
      return rc.getString(key);
    } catch (e) {
      debugPrint('Remote Config force fetch failed for "$key": $e');
      // Fall back to whatever is cached/activated.
      return getString(key);
    }
  }
}
