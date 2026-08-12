import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/licensing/license_repository.dart';

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key, required this.repository});

  final LicenseRepository repository;

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_refresh);
    _code.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _activate() async {
    try {
      await widget.repository.activate(_code.text);
      if (!mounted) return;
      _code.clear();
      _show('License activated.');
    } catch (error) {
      _show(error.toString());
    }
  }

  Future<void> _refreshLicense() async {
    try {
      await widget.repository.refresh();
      _show('License refreshed.');
    } catch (error) {
      _show(error.toString());
    }
  }

  Future<void> _deactivate() async {
    await widget.repository.deactivate();
    _show('This device is now using the Free plan.');
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = widget.repository.entitlement;
    final commercial = entitlement.isCommercial && entitlement.leaseToken.isNotEmpty;
    final expires = entitlement.expiresAt;
    final offlineUntil = entitlement.offlineUntil;

    return Scaffold(
      appBar: AppBar(title: const Text('Plan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        commercial ? Icons.verified_outlined : Icons.shield_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${entitlement.planLabel} plan',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Firewall profiles: up to ${entitlement.maxFirewalls}'),
                  Text(entitlement.adsEnabled ? 'Advertising: enabled' : 'Advertising: disabled'),
                  const Text('Firewall management features: enabled'),
                  if (entitlement.licenseId.isNotEmpty)
                    Text('License ID: ${entitlement.licenseId}'),
                  if (expires != null) Text('Expires: ${_date(expires)}'),
                  if (offlineUntil != null)
                    Text('Offline grace until: ${_date(offlineUntil)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!commercial && !AppInfo.commercialLicensingEnabled)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sentinel Free',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The Free edition manages one firewall and keeps the full firewall, NAT, network, VPN, diagnostics, user, service and captive-portal feature set available.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Free is supported by advertising on the main overview screens. Ads are not shown while entering credentials or while using add/edit/action screens.',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.workspace_premium_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Sentinel Pro is planned for a later release with multiple-firewall management and no ads. No purchase flow is enabled in this Free build.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else if (!commercial) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activate a commercial license',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter the activation code supplied with your Personal, Professional or MSP entitlement.',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _code,
                      enabled: !widget.repository.busy,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Activation code',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.repository.busy ? null : _activate,
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Activate license'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.repository.busy ? null : _refreshLicense,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.repository.busy ? null : _deactivate,
                    icon: const Icon(Icons.logout),
                    label: const Text('Deactivate'),
                  ),
                ),
              ],
            ),
          ],
          if (AppInfo.commercialLicensingEnabled) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How commercial licensing works',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Commercial entitlements use an opaque lease token and a randomly generated installation identifier stored in secure platform storage. Firewall API credentials are never sent to the licensing service.',
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '${AppInfo.name} ${AppInfo.version} (${AppInfo.buildNumber}) · ${AppInfo.packageId}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}
