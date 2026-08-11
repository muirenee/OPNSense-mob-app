# Build status — v0.4.0

The repository is normalized as a standard Flutter application with committed Android and iOS platform wrappers.

Verified on GitHub Actions with Flutter 3.44.7 / Dart 3.12.2:
- Flutter analyze completed without fatal errors
- all 13 project tests passed
- Android release APK compiled successfully
- APK existence and SHA-256 verification passed

Repository normalization also removed the temporary `.ci/source.part*` transport files and bootstrap files. The permanent `.github/workflows/build-apk.yml` builds directly from the repository root.

Android release configuration includes the required `INTERNET` permission and the product display name `Netsource OPN Manager`.
