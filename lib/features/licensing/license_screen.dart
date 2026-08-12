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
    final commercial = entitlement.leaseToken.isNotEmpty;
    final expires = entitlement.expiresAt;
    final offlineUntil = entitlement.offlineUntil;

    return Scaffold(
      appBar: AppBar(title: const Text('License & subscription')),
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
                  Text('Status: ${entitlement.status.name}'),
                  Text('Firewall profiles: up to ${entitlement.maxFirewalls}'),
                  if (entitlement.licenseId.isNotEmpty)
                    Text('License ID: ${entitlement.licenseId}'),
                  if (expires != null)
                    Text('Expires: ${_date(expires)}'),
                  if (offlineUntil != null)
                    Text('Offline grace until: ${_date(offlineUntil)}'),
                  const SizedBox(height: 8),
                  Text(
                    'Installation ID: ${widget.repository.installationId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!commercial) ...[
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
                      'Enter the activation code supplied with your Personal, Professional or MSP subscription.',
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
                    if (!widget.repository.serviceConfigured) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'This preview build does not have a licensing service URL configured. The client-side licensing framework is enabled; production builds must set SENTINEL_LICENSE_API_URL.',
                      ),
                    ],
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
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How licensing works',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Netsource Sentinel uses an opaque lease token issued by the licensing service. '
                    'The token and installation identifier are stored in secure platform storage. '
                    'Firewall API credentials are never sent to the licensing service.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Paid entitlements can include an offline grace period so firewall management does not stop immediately during a temporary Internet or licensing-service outage.',
                  ),
                ],
              ),
            ),
          ),
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
