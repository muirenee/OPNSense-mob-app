class AppInfo {
  const AppInfo._();

  static const String name = 'Netsource Sentinel';
  static const String version = '1.0.2';
  static const int buildNumber = 102;
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

  /// Set at build time for commercial releases:
  /// --dart-define=SENTINEL_LICENSE_API_URL=https://license.example.com
  static const String licenseApiUrl = String.fromEnvironment(
    'SENTINEL_LICENSE_API_URL',
    defaultValue: '',
  );
}
