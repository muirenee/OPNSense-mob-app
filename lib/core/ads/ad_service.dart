import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app_info.dart';

/// Diagnostic bridge for GMA Next-Gen initialization.
///
/// This build intentionally does not request consent and does not create an ad
/// view. It only asks Android to initialize the separate GMA Next-Gen SDK after
/// Sentinel is already usable, so we can establish whether that engine is
/// stable on the real device before adding UMP or banner rendering.
class AdService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel(
    'com.netsource.sentinel/ads_diag',
  );

  bool _initialized = false;
  String? _lastError;

  bool get initialized => _initialized;
  bool get canRequestAds => false;
  bool get privacyOptionsRequired => false;
  bool get usingTestAds => AppInfo.usesTestAds;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _channel.invokeMethod<bool>('initializeNextGen', <String, Object>{
        'appId': AppInfo.adMobAppId,
      });
      _lastError = null;
    } on PlatformException catch (error) {
      _lastError = error.message ?? error.code;
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> showPrivacyOptions() async {}
}
