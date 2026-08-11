import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../profiles/firewall_profile.dart';
import 'firmware_repository.dart';

class FirmwareScreen extends StatefulWidget {
  const FirmwareScreen({super.key, required this.profile, required this.credentials});

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<FirmwareScreen> createState() => _FirmwareScreenState();
}

class _FirmwareScreenState extends State<FirmwareScreen> {
  late final FirmwareRepository _repository;
  late Future<FirmwareStatus> _future;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _repository = FirmwareRepository(
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
    );
    _future = _repository.check();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.check());
    await _future;
  }

  Future<void> _install(FirmwareStatus status) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Install firewall updates?'),
            content: Text(
              'Install ${status.updates} available update${status.updates == 1 ? '' : 's'}'
              '${status.downloadSize.isEmpty ? '' : ' (${status.downloadSize})'}?\n\n'
              'Services may restart and the firewall may require a reboot. Keep an alternate management path available.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Install')),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _installing = true);
    try {
      await _repository.installUpdates();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update installation started. The firewall may temporarily become unavailable.')),
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to start updates: $error')));
      }
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System updates')),
      body: FutureBuilder<FirmwareStatus>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error, onRetry: _refresh);
          }
          final status = snapshot.data!;
          final ok = status.status.toLowerCase() == 'ok';
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: (status.hasUpdates ? Colors.orange : Colors.green).withValues(alpha: .12),
                              child: Icon(
                                status.hasUpdates ? Icons.system_update_alt : Icons.verified_outlined,
                                color: status.hasUpdates ? Colors.orange : Colors.green,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    status.hasUpdates ? 'Updates available' : (ok ? 'System is up to date' : 'Update status'),
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  if (status.message.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(status.message),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _ValueRow(label: 'Packages', value: status.updates.toString()),
                        if (status.downloadSize.isNotEmpty) _ValueRow(label: 'Download', value: status.downloadSize),
                        _ValueRow(label: 'Reboot', value: status.needsReboot ? 'Required' : 'Not indicated'),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _installing ? null : _refresh,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Check again'),
                              ),
                            ),
                            if (status.hasUpdates) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _installing ? null : () => _install(status),
                                  icon: _installing
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.download_for_offline_outlined),
                                  label: Text(_installing ? 'Starting…' : 'Install'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.security_outlined),
                    title: const Text('Update safety'),
                    subtitle: const Text('Major upgrades or remote-only maintenance should be planned with an alternate console or recovery path.'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update_alt, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text('Update check unavailable', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: () => onRetry(), icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
}
