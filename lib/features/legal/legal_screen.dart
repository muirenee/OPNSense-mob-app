import 'package:flutter/material.dart';

import '../../core/app_info.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Legal & privacy'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Privacy'),
              Tab(text: 'EULA'),
              Tab(text: 'Notices'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LegalDocument(title: 'Privacy Policy', text: _privacy),
            _LegalDocument(title: 'End User License Agreement', text: _eula),
            _LegalDocument(title: 'Third-Party Notices', text: _notices),
          ],
        ),
      ),
    );
  }
}

class _LegalDocument extends StatelessWidget {
  const _LegalDocument({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        SelectableText(text),
        const SizedBox(height: 18),
        SelectableText('Contact: ${AppInfo.supportEmail}'),
      ],
    );
  }
}

const _privacy = '''Effective: 12 August 2026

Netsource Sentinel is a mobile management client for firewalls that expose compatible OPNsense APIs.

Firewall connection data
The app stores firewall profiles locally on the device. API keys and API secrets are stored using platform secure storage. Firewall API credentials are sent only to the firewall address configured by the user. They are not sent to Google, advertisers or the Netsource Sentinel licensing service.

Free edition and advertising
Netsource Sentinel Free supports one saved firewall and uses Google AdMob through the Google Mobile Ads SDK to display advertising on selected overview screens. Ads are not shown in Demo Mode or on credential, add/edit and operational action screens.

Advertising services may process information such as device or advertising identifiers, IP address, general device/app information, ad interactions, diagnostics and information needed for advertising delivery, measurement, fraud prevention and compliance. Google's processing is governed by its own terms and privacy policies. Netsource Sentinel does not sell or provide firewall API credentials to advertisers.

Consent and privacy choices
The app uses Google's User Messaging Platform consent tools. Where required, a consent message is shown before ads are requested. Where Google indicates that privacy options must remain available, Sentinel exposes an Ad privacy choices entry so the user can review or change those choices.

Licensing data
The public Free build does not require a licensing server. Future commercial builds may send an activation code, a randomly generated installation identifier, app package identifier, app version/build number and an opaque entitlement token to the Netsource Sentinel licensing service. That service does not require or receive firewall API keys or secrets.

Demo Mode
Demo Mode uses local sample data and does not contact a firewall. Advertising is suppressed while the Demo profile is active.

Security
Sensitive local values are stored using secure-storage facilities supplied by the operating system. Connections to real firewalls use HTTPS when configured by the user. A self-signed-certificate option is available only for trusted firewalls controlled by the user.

Retention and deletion
Deleting a firewall profile removes its locally stored API credentials. Uninstalling the application removes application-local data subject to the operating system's backup and restore behavior. Advertising data handled by Google is retained according to Google's applicable policies and the user's privacy choices.

Questions or deletion requests
Contact the support address shown below for questions about Sentinel's privacy practices or locally managed product data.
''';

const _eula = '''Netsource Sentinel End User License Agreement
Effective: 12 August 2026

1. License grant
Subject to compliance with this agreement, the publisher grants the user a limited, non-exclusive, non-transferable right to install and use Netsource Sentinel for lawful administration of systems the user owns or is authorized to manage.

2. Free edition
Netsource Sentinel Free permits one saved firewall profile and provides the supported management feature set for that firewall. The Free edition may display advertising on non-sensitive overview screens.

3. Future paid plans
The publisher may later offer paid plans such as Sentinel Pro or MSP with different firewall limits, ad-free use or additional features. No paid purchase is required or offered by the current Free build. Future commercial entitlements may be validated periodically and may include an offline grace period.

4. Acceptable use
The user must not use Netsource Sentinel to obtain unauthorized access to networks, devices or data. The user is responsible for firewall changes performed through the application and for maintaining appropriate backups and administrative access.

5. Credentials
The user is responsible for creating least-privilege firewall API credentials and protecting them. The application stores API credentials locally using operating-system secure storage and does not provide those credentials to advertising services.

6. Third-party software, services and trademarks
Netsource Sentinel is an independent management application. OPNsense is a trademark of Deciso B.V. Netsource Sentinel is not affiliated with, endorsed by or produced by Deciso B.V. The Free edition uses Google advertising and consent-management services. Third-party components and services remain subject to their respective licenses and terms.

7. Updates
The publisher may provide updates to maintain compatibility, security and functionality. Some features may depend on firewall versions, plugins or API privileges and therefore may not be available on every installation.

8. No warranty
To the maximum extent permitted by applicable law, the software is provided on an as-is and as-available basis without warranties that every firewall configuration, plugin or API version will be supported.

9. Limitation of liability
To the maximum extent permitted by applicable law, the publisher is not liable for indirect, incidental or consequential loss arising from use of the application. The user remains responsible for reviewing and validating changes applied to production firewalls.

10. Contact
Questions about this agreement should be sent to the support address shown below.
''';

const _notices = '''OPNsense
Netsource Sentinel interoperates with OPNsense APIs. OPNsense is distributed under the BSD 2-Clause license. OPNsense and its associated marks are owned by their respective rights holders. This application is independently developed and is not an official OPNsense product.

Flutter and Dart
The application is built with Flutter and Dart and includes open-source packages distributed under their respective licenses.

Google Mobile Ads
The Free edition integrates the Google Mobile Ads SDK and Google's User Messaging Platform through the google_mobile_ads Flutter plugin. Google advertising and consent services are subject to Google's applicable terms and privacy policies.

Flutter dependencies
Direct dependencies include dio, flutter_secure_storage, google_mobile_ads, shared_preferences and cupertino_icons. Complete dependency-license notices should be regenerated from the resolved release dependencies for each public release.

Netsource Sentinel
Copyright © 2026. All rights reserved except for third-party components distributed under their own licenses.
''';
