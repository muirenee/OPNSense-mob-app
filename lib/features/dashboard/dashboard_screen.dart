import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../../features/profiles/firewall_profile.dart';
import 'dashboard_models.dart';
import 'dashboard_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.profile,
    required this.credentials,
  });

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardRepository _repository;
  late Future<DashboardSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _repository = DashboardRepository(
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
    );
    _future = _repository.load();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error, onRetry: _refresh);
        }
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text(
                widget.profile.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(widget.profile.baseUrl),
              const SizedBox(height: 18),
              _SectionCard(
                title: 'System',
                icon: Icons.shield_outlined,
                child: _JsonHighlights(
                  map: data.systemInformation,
                  preferredKeys: const [
                    'hostname',
                    'product_version',
                    'version',
                    'uptime',
                    'platform',
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SectionCard(
                      title: 'Memory',
                      icon: Icons.memory,
                      child: _CompactJson(map: data.memory),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SectionCard(
                      title: 'Disk',
                      icon: Icons.storage_outlined,
                      child: _CompactJson(map: data.disk),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Interfaces',
                icon: Icons.lan_outlined,
                child: data.interfaces.isEmpty
                    ? const Text('No interface records returned by this API user.')
                    : Column(
                        children: [
                          for (var i = 0; i < data.interfaces.length; i++) ...[
                            if (i > 0) const Divider(height: 18),
                            _InterfaceRow(interface: data.interfaces[i]),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InterfaceRow extends StatelessWidget {
  const _InterfaceRow({required this.interface});

  final InterfaceSummary interface;

  @override
  Widget build(BuildContext context) {
    final color = interface.isUp
        ? Colors.green
        : Theme.of(context).colorScheme.outline;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Icon(Icons.circle, size: 10, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                interface.description,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text('${interface.identifier} · ${interface.status}'),
              if (interface.addresses.isNotEmpty)
                Text(interface.addresses.join('  ·  ')),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _JsonHighlights extends StatelessWidget {
  const _JsonHighlights({required this.map, required this.preferredKeys});

  final Map<String, dynamic> map;
  final List<String> preferredKeys;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, dynamic>>[];
    for (final key in preferredKeys) {
      if (map.containsKey(key)) rows.add(MapEntry(key, map[key]));
    }
    if (rows.isEmpty) rows.addAll(map.entries.take(5));

    return Column(
      children: rows
          .map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(_label(entry.key)),
                    ),
                    Expanded(
                      child: Text(
                        _value(entry.value),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _CompactJson extends StatelessWidget {
  const _CompactJson({required this.map});

  final Map<String, dynamic> map;

  @override
  Widget build(BuildContext context) {
    final entries = map.entries.take(3).toList();
    if (entries.isEmpty) return const Text('No data');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('${_label(entry.key)}: ${_value(entry.value)}'),
              ))
          .toList(),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Dashboard unavailable',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _label(String value) {
  final text = value.replaceAll('_', ' ').trim();
  if (text.isEmpty) return value;
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

String _value(dynamic value) {
  if (value == null) return '—';
  if (value is Map || value is List) return value.toString();
  return value.toString();
}
