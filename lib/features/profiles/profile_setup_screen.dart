import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../../core/storage/profile_repository.dart';
import 'firewall_profile.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.repository,
    this.initialProfile,
  });

  final ProfileRepository repository;
  final FirewallProfile? initialProfile;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  final _apiKey = TextEditingController();
  final _apiSecret = TextEditingController();
  bool _allowSelfSigned = false;
  bool _obscureSecret = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.initialProfile?.name ?? 'My OPNsense',
    );
    _url = TextEditingController(
      text: widget.initialProfile?.baseUrl ?? 'https://',
    );
    _allowSelfSigned =
        widget.initialProfile?.allowSelfSignedCertificate ?? false;
    _loadExistingCredentials();
  }

  Future<void> _loadExistingCredentials() async {
    final profile = widget.initialProfile;
    if (profile == null) return;
    final credentials = await widget.repository.credentialsFor(profile.id);
    if (!mounted || credentials == null) return;
    _apiKey.text = credentials.apiKey;
    _apiSecret.text = credentials.apiSecret;
    setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _apiKey.dispose();
    _apiSecret.dispose();
    super.dispose();
  }

  Future<void> _saveAndConnect() async {
    if (_name.text.trim().isEmpty ||
        _url.text.trim().isEmpty ||
        _apiKey.text.trim().isEmpty ||
        _apiSecret.text.isEmpty) {
      setState(() => _message = 'Complete all connection fields.');
      return;
    }

    setState(() {
      _busy = true;
      _message = 'Testing connection…';
    });

    final profile = FirewallProfile(
      id: widget.initialProfile?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      baseUrl: OpnSenseApiClient.normalizeBaseUrl(_url.text),
      allowSelfSignedCertificate: _allowSelfSigned,
    );
    final credentials = FirewallCredentials(
      apiKey: _apiKey.text.trim(),
      apiSecret: _apiSecret.text,
    );

    try {
      final api = OpnSenseApiClient(profile: profile, credentials: credentials);
      await api.testConnection();
      await widget.repository.saveProfile(profile, credentials);
      if (!mounted) return;
      setState(() => _message = 'Connected.');
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteProfile(FirewallProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete firewall profile?'),
        content: Text(
          'Remove ${profile.name} and its locally stored API credentials from this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.repository.delete(profile.id);
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.repository.profiles;
    final isEditing = widget.initialProfile != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit firewall' : 'OPNsense firewalls'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!isEditing && profiles.isNotEmpty) ...[
              Text(
                'Saved firewalls',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < profiles.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.shield_outlined),
                        title: Text(
                          profiles[i].name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(profiles[i].baseUrl),
                        onTap: () => widget.repository.select(profiles[i].id),
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ProfileSetupScreen(
                                      repository: widget.repository,
                                      initialProfile: profiles[i],
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => _deleteProfile(profiles[i]),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Add another firewall',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
            ],
            Icon(
              Icons.shield_outlined,
              size: 58,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              'Netsource OPN Manager',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Connect directly to your OPNsense API. Credentials are stored in platform secure storage.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Firewall name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Firewall URL or IP',
                hintText: 'https://192.168.1.1',
                prefixIcon: Icon(Icons.language),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKey,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'API key',
                prefixIcon: Icon(Icons.key_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiSecret,
              obscureText: _obscureSecret,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'API secret',
                prefixIcon: const Icon(Icons.password_outlined),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscureSecret = !_obscureSecret),
                  icon: Icon(
                    _obscureSecret ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _allowSelfSigned,
              onChanged: (value) => setState(() => _allowSelfSigned = value),
              title: const Text('Allow self-signed certificate'),
              subtitle: const Text(
                'Use only for a trusted firewall you control. Valid CA certificates remain recommended.',
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _message == 'Connected.'
                      ? Colors.green
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _saveAndConnect,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: Text(
                _busy
                    ? 'Connecting…'
                    : isEditing
                        ? 'Test & save'
                        : 'Test & connect',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
