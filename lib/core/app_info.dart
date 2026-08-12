class AppInfo {
  const AppInfo._();

  static const String name = 'Netsource Sentinel';
  static const String version = '1.1.2';
  static const int buildNumber = 112;
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

  /// Recovery build: advertising is disabled at binary level while the startup
  /// crash introduced by the first ad-supported release is isolated. The Free
  /// entitlement remains limited to one firewall and the ad architecture stays
  /// available for a later safe reintroduction.
  static const bool adsEnabled = false;
  static const String adMobBannerAdUnitId = '';
  static const bool usesTestAds = false;

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
