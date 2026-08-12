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
The app stores firewall profiles locally on the device. API keys and API secrets are stored using platform secure storage. Firewall API credentials are sent only to the firewall address configured by the user and are not sent to the Netsource Sentinel licensing service.

Licensing data
Commercial builds may send an activation code, a randomly generated installation identifier, app package identifier, app version and build number to the Netsource Sentinel licensing service. The licensing service does not require or receive firewall API keys or secrets.

Demo mode
Demo Mode uses local sample data and does not contact a firewall.

Data sharing and advertising
The application does not contain advertising SDKs. Netsource Sentinel does not sell firewall credentials or licensing data to advertisers.

Security
Sensitive local values are stored using the secure-storage facilities supplied by the operating system. Connections to real firewalls use HTTPS when configured by the user. A self-signed-certificate option is available only for firewalls the user controls.

Retention and deletion
Deleting a firewall profile removes its locally stored API credentials. Deactivating a license removes the locally cached commercial entitlement. Uninstalling the application removes application-local data subject to the operating system's backup and restore behavior. Licensing records retained by the licensing service are kept only as necessary for subscription administration, fraud prevention, support, accounting and legal obligations.

Questions or deletion requests
Contact the support address shown below for privacy questions or requests relating to licensing records.
''';

const _eula = '''Netsource Sentinel End User License Agreement
Effective: 12 August 2026

1. License grant
Subject to payment of any applicable fees and compliance with this agreement, the publisher grants the user a limited, non-exclusive, non-transferable right to install and use Netsource Sentinel for lawful administration of systems the user owns or is authorized to manage.

2. Subscription and device limits
Commercial plans may limit the number of firewall profiles, installations or enabled features. License entitlements may be periodically validated and may include an offline grace period.

3. Acceptable use
The user must not use Netsource Sentinel to obtain unauthorized access to networks, devices or data. The user is responsible for firewall changes performed through the application and for maintaining appropriate backups and administrative access.

4. Credentials
The user is responsible for creating least-privilege firewall API credentials and protecting them. The application stores API credentials locally using operating-system secure storage.

5. Third-party software and trademarks
Netsource Sentinel is an independent management application. OPNsense is a trademark of Deciso B.V. Netsource Sentinel is not affiliated with, endorsed by or produced by Deciso B.V. Third-party open-source components remain subject to their respective licenses.

6. Updates
The publisher may provide updates to maintain compatibility, security and functionality. Some features may depend on firewall versions, plugins or API privileges and therefore may not be available on every installation.

7. No warranty
To the maximum extent permitted by applicable law, the software is provided on an as-is and as-available basis without warranties that every firewall configuration, plugin or API version will be supported.

8. Limitation of liability
To the maximum extent permitted by applicable law, the publisher is not liable for indirect, incidental or consequential loss arising from use of the application. The user remains responsible for reviewing and validating changes applied to production firewalls.

9. Termination
The license may be suspended or terminated for material breach, fraudulent activation or non-payment. Termination does not affect obligations that by their nature survive termination.

10. Contact
Questions about commercial licensing or this agreement should be sent to the support address shown below.
''';

const _notices = '''OPNsense
Netsource Sentinel interoperates with OPNsense APIs. OPNsense is distributed under the BSD 2-Clause license. OPNsense and its associated marks are owned by their respective rights holders. This application is independently developed and is not an official OPNsense product.

Flutter
The application is built with Flutter and Dart and includes open-source packages distributed under their respective licenses.

Included Flutter packages currently include dio, flutter_secure_storage, shared_preferences and cupertino_icons. Complete source-license notices for dependency versions should be regenerated as part of each release audit.

Netsource Sentinel
Copyright © 2026. All rights reserved except for third-party components distributed under their own licenses.
''';
