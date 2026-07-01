import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'remote_config_service.dart';

/// Holds the outcome of the mandatory-update check performed once at app
/// startup (see main.dart). Read synchronously by the router's redirect
/// callback, so this is intentionally a plain static holder rather than a
/// Riverpod provider — GoRouter's redirect needs an already-known value, not
/// something to await.
abstract final class ForceUpdateGate {
  static bool required = false;
  static String updateUrl = '';

  /// Compares the installed app version against the 'min_supported_version'
  /// remote-config value and stores the result. Call once, right after
  /// RemoteConfigService.init() and before runApp().
  static Future<void> check(RemoteConfigService remoteConfig) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final installed = info.version; // e.g. "1.0.0"
      final minRequired = remoteConfig.getString('min_supported_version');

      if (minRequired.trim().isEmpty) {
        required = false;
        return;
      }

      required = _compare(installed, minRequired) < 0;
      updateUrl = Platform.isIOS
          ? remoteConfig.getString('update_url_ios')
          : remoteConfig.getString('update_url_android');

      if (required) {
        debugPrint(
          'Force update required: installed=$installed min=$minRequired',
        );
      }
    } catch (e) {
      debugPrint('Force-update check failed: $e');
      required = false; // never lock users out just because the check failed
    }
  }

  /// Returns -1 if [a] < [b], 0 if equal, 1 if [a] > [b]. Compares dotted
  /// numeric version strings (e.g. "1.2.0" vs "1.10.3"), ignoring anything
  /// after a '+' or '-' (build metadata / pre-release suffixes).
  static int _compare(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  static List<int> _parts(String v) {
    final clean = v.split('+').first.split('-').first;
    return clean.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
  }
}
