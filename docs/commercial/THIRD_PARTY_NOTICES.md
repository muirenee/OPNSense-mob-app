# Netsource Sentinel — Third-Party Notices

## OPNsense interoperability
Netsource Sentinel interoperates with OPNsense APIs. OPNsense is distributed under the BSD 2-Clause license. OPNsense and associated marks are owned by their respective rights holders. Netsource Sentinel is independently developed and is not an official OPNsense product and is not affiliated with, endorsed by or produced by Deciso B.V.

Before publication, preserve the applicable OPNsense BSD license/copyright notice for any OPNsense source material that is actually redistributed in the application or repository. API interoperability by itself does not transfer ownership of the OPNsense trademarks.

## Flutter and Dart
Netsource Sentinel is built with Flutter and Dart. Their source code and binary components are distributed under their applicable open-source licenses.

## Google Mobile Ads and consent services
Netsource Sentinel Free integrates Google Mobile Ads / AdMob and Google's User Messaging Platform through the `google_mobile_ads` Flutter plugin. These components and services are subject to Google's applicable software licenses, service terms and privacy policies.

The application uses Google-provided sample/test advertising identifiers in development and CI builds. A public production build must use the publisher's own AdMob application and ad-unit identifiers.

## Direct Flutter dependencies in v1.1
The current pubspec includes:
- `cupertino_icons`
- `dio`
- `flutter_secure_storage`
- `google_mobile_ads`
- `shared_preferences`

Each package and its transitive dependencies remains subject to its own license. A production release should generate an exact dependency-license inventory from the resolved lockfile and archive it with the release evidence.

## Netsource Sentinel application code
Except for third-party components and material explicitly distributed under another license, the Netsource Sentinel application code is proprietary to its rights holder. Copyright © 2026. All rights reserved.

## Release checklist for notices
- Re-run dependency license inventory whenever `pubspec.lock` changes.
- Keep attribution notices bundled in the application where a dependency license requires it.
- Keep Google advertising/privacy disclosures aligned with the actual production SDK configuration.
- Do not use the OPNsense logo or a derivative brand mark without confirming applicable trademark permission.
- Keep the independent-product disclaimer in the Play listing and in-app legal page.
