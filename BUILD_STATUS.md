# Build status — v0.4.0

The repository has been normalized as a standard Flutter application with generated Android and iOS platform wrappers committed to source control.

Verified on GitHub Actions with Flutter 3.44.7 / Dart 3.12.2:
- source transport checksum verified before normalization
- Flutter analyze completed without fatal errors
- all 13 project tests passed
- Android release APK compiled successfully
- APK existence and SHA-256 verification passed

The normalized `.github/workflows/android.yml` builds directly from the repository root; no source reconstruction or transport chunks are required anymore.
