import '../app_info.dart';

class AdConfig {
  const AdConfig._();

  static bool get enabled => AppInfo.adsEnabled;
  static String get bannerAdUnitId => AppInfo.adMobBannerAdUnitId;
  static bool get usingTestAds => AppInfo.usesTestAds;
}
