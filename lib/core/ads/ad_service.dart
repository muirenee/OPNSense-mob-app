import 'package:flutter/foundation.dart';

/// No-op advertising service used by the v1.1.2 recovery build.
///
/// The Free entitlement and UI hooks remain intact, but the Google Mobile Ads
/// native plugin is deliberately not linked into this binary. This lets us
/// prove whether the launch regression is inside the advertising SDK layer.
class AdService extends ChangeNotifier {
  bool get initialized => true;
  bool get canRequestAds => false;
  bool get privacyOptionsRequired => false;
  bool get usingTestAds => false;
  String? get lastError => null;

  Future<void> initialize() async {}

  Future<void> showPrivacyOptions() async {}
}
