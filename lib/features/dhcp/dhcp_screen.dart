import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../profiles/firewall_profile.dart';
import 'dhcp_models.dart';
import 'dhcp_repository.dart';

class DhcpScreen extends StatefulWidget {
  const DhcpScreen({super.key, required this.profile, required this.credentials});

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<DhcpScreen> createState() => _DhcpScreenState();
}

class _DhcpScreenState extends State<DhcpScreen> {
  late final DhcpRepository _repository;
  late Future<List<DhcpLeaseSummary>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repository = DhcpRepository(
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
    );
    _future = _repository.loadLeases();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.loadLeases());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DhcpLeaseSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorPane(title: 'DHCP leases unavailable', error: snapshot.error, onRetry: _refresh);
        }
        final all = snapshot.data ?? const <DhcpLeaseSummary>[];
        final q = _query.trim().toLowerCase();
        final leases = q.isEmpty
            ? all
            : all.where((item) =>
                item.ip.toLowerCase().contains(q) ||
                item.mac.toLowerCase().contains(q) ||
                item.hostname.toLowerCase().contains(q) ||
                item.interfaceName.toLowerCase().contains(q)).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text('DHCP leases', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${all.length} lease${all.length == 1 ? '' : 's'}'),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search IP, MAC or hostname'),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              for (final lease in leases) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.devices_outlined),
                    title: Text(lease.hostname.isEmpty ? lease.ip : lease.hostname, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      lease.ip,
                      lease.mac,
                      if (lease.interfaceName.isNotEmpty) lease.interfaceName,
                      if (lease.state.isNotEmpty) lease.state,
                      if (lease.ends.isNotEmpty) 'expires ${lease.ends}',
                      if (lease.source.isNotEmpty) lease.source,
                    ].where((item) => item.isNotEmpty).join(' · ')),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (leases.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No matching leases returned.'))),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.title, required this.error, required this.onRetry});
  final String title;
  final Object? error;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => onRetry(), icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ]),
        ),
      );
}
