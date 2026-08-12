class AppInfo {
  const AppInfo._();

  static const String name = 'Netsource Sentinel';
  static const String version = '1.1.3';
  static const int buildNumber = 113;
  static const String packageId = 'com.netsource.sentinel';
  static const String supportEmail = 'support@fidalix.com';

  /// Production builds can point these to the public pages configured in
  /// Google Play. Keeping the defaults empty prevents preview builds from
  /// advertising URLs that may not have been published yet.
  static const String privacyPolicyUrl = String.fromEnvironment(
    'SENTINEL_PRIVACY_POLICY_URL',
    defaultValue: '',
  );
  static const String termsUrl = String.fromEnvironment(
    'SENTINEL_TERMS_URL',
    defaultValue: '',
  );

  /// Free releases are ad-supported by default. Ads are implemented through a
  /// Sentinel-owned native Android bridge rather than the google_mobile_ads
  /// Flutter plugin, which caused the v1.1.0/v1.1.1 launch crash on the test
  /// device. The bridge fails open: an ads/consent failure never blocks the
  /// firewall manager.
  static const bool adsEnabled = bool.fromEnvironment(
    'SENTINEL_ADS_ENABLED',
    defaultValue: true,
  );

  /// Google's dedicated Android fixed-size banner test unit. Production Play
  /// builds replace this with Sentinel's AdMob banner unit using --dart-define.
  static const String googleTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  static const String adMobBannerAdUnitId = String.fromEnvironment(
    'SENTINEL_ADMOB_BANNER_ID',
    defaultValue: googleTestBannerAdUnitId,
  );

  static bool get usesTestAds =>
      adMobBannerAdUnitId == googleTestBannerAdUnitId;

  /// Keep commercial activation dormant in the public Free release. The
  /// licensing architecture remains in place so Play Billing or the Sentinel
  /// license backend can enable Pro/MSP later without changing app identity.
  static const bool commercialLicensingEnabled = bool.fromEnvironment(
    'SENTINEL_COMMERCIAL_LICENSING_ENABLED',
    defaultValue: false,
  );

  /// Future commercial releases can point this at the entitlement service.
  static const String licenseApiUrl = String.fromEnvironment(
    'SENTINEL_LICENSE_API_URL',
    defaultValue: '',
  );
}
