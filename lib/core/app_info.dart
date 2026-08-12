class AppInfo {
  const AppInfo._();

  static const String name = 'Netsource Sentinel';
  static const String version = '1.1.4';
  static const int buildNumber = 114;
  static const String packageId = 'com.netsource.sentinel';
  static const String supportEmail = 'support@fidalix.com';

  static const String privacyPolicyUrl = String.fromEnvironment(
    'SENTINEL_PRIVACY_POLICY_URL',
    defaultValue: '',
  );
  static const String termsUrl = String.fromEnvironment(
    'SENTINEL_TERMS_URL',
    defaultValue: '',
  );

  /// Diagnostic candidate: initialize Google's separate GMA Next-Gen Android
  /// SDK after Sentinel is already running. No UMP and no banner are loaded in
  /// this build; the purpose is to isolate the ads engine itself.
  static const bool adsEnabled = true;
  static const String googleTestAdMobAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String adMobAppId = String.fromEnvironment(
    'SENTINEL_ADMOB_APP_ID',
    defaultValue: googleTestAdMobAppId,
  );
  static const String adMobBannerAdUnitId = '';
  static bool get usesTestAds => adMobAppId == googleTestAdMobAppId;

  static const bool commercialLicensingEnabled = bool.fromEnvironment(
    'SENTINEL_COMMERCIAL_LICENSING_ENABLED',
    defaultValue: false,
  );

  static const String licenseApiUrl = String.fromEnvironment(
    'SENTINEL_LICENSE_API_URL',
    defaultValue: '',
  );
}
