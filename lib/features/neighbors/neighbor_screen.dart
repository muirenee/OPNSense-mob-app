import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../profiles/firewall_profile.dart';
import 'neighbor_models.dart';
import 'neighbor_repository.dart';

class NeighborScreen extends StatefulWidget {
  const NeighborScreen({super.key, required this.profile, required this.credentials});
  final FirewallProfile profile;
  final FirewallCredentials credentials;
  @override
  State<NeighborScreen> createState() => _NeighborScreenState();
}

class _NeighborScreenState extends State<NeighborScreen> {
  late final NeighborRepository _repository;
  late Future<List<NeighborSummary>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repository = NeighborRepository(OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials));
    _future = _repository.load();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NeighborSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Neighbor table unavailable\n${snapshot.error}', textAlign: TextAlign.center)));
        final all = snapshot.data ?? const <NeighborSummary>[];
        final q = _query.toLowerCase().trim();
        final rows = q.isEmpty ? all : all.where((item) => '${item.ip} ${item.mac} ${item.hostname} ${item.interfaceName}'.toLowerCase().contains(q)).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text('ARP / NDP neighbors', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search neighbor'), onChanged: (value) => setState(() => _query = value)),
              const SizedBox(height: 12),
              for (final item in rows) ...[
                Card(child: ListTile(
                  leading: CircleAvatar(child: Text(item.type)),
                  title: Text(item.hostname.isEmpty ? item.ip : item.hostname, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([item.ip, item.mac, item.interfaceName, item.status].where((value) => value.isNotEmpty).join(' · ')),
                )),
                const SizedBox(height: 8),
              ],
              if (rows.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No matching neighbors returned.'))),
            ],
          ),
        );
      },
    );
  }
}
