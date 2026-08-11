import 'package:flutter/material.dart';

import '../../../core/api/opnsense_api_client.dart';
import '../../profiles/firewall_profile.dart';
import 'firewall_state_models.dart';
import 'firewall_state_repository.dart';

class FirewallStateScreen extends StatefulWidget {
  const FirewallStateScreen({super.key, required this.profile, required this.credentials});
  final FirewallProfile profile;
  final FirewallCredentials credentials;
  @override
  State<FirewallStateScreen> createState() => _FirewallStateScreenState();
}

class _FirewallStateScreenState extends State<FirewallStateScreen> {
  late final FirewallStateRepository _repository;
  late Future<List<FirewallStateSummary>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repository = FirewallStateRepository(OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials));
    _future = _repository.load();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FirewallStateSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Firewall states unavailable\n${snapshot.error}', textAlign: TextAlign.center)));
        final all = snapshot.data ?? const <FirewallStateSummary>[];
        final q = _query.toLowerCase().trim();
        final rows = q.isEmpty ? all : all.where((item) => '${item.source} ${item.destination} ${item.protocol} ${item.interfaceName} ${item.state}'.toLowerCase().contains(q)).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text('Active states', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${all.length} state${all.length == 1 ? '' : 's'} returned'),
              const SizedBox(height: 12),
              TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search source, destination or protocol'), onChanged: (value) => setState(() => _query = value)),
              const SizedBox(height: 12),
              for (final item in rows) ...[
                Card(child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${item.protocol}${item.direction.isEmpty ? '' : ' · ${item.direction}'}', style: const TextStyle(fontWeight: FontWeight.w800))),
                      if (item.interfaceName.isNotEmpty) Text(item.interfaceName),
                    ]),
                    const SizedBox(height: 8),
                    Text('Source: ${item.source.isEmpty ? '—' : item.source}'),
                    Text('Destination: ${item.destination.isEmpty ? '—' : item.destination}'),
                    if (item.state.isNotEmpty) Text('State: ${item.state}'),
                    if (item.age.isNotEmpty || item.expires.isNotEmpty) Text('Age ${item.age.isEmpty ? '—' : item.age} · Expires ${item.expires.isEmpty ? '—' : item.expires}'),
                    if (item.packets.isNotEmpty || item.bytes.isNotEmpty) Text('Packets ${item.packets.isEmpty ? '—' : item.packets} · Bytes ${item.bytes.isEmpty ? '—' : item.bytes}'),
                  ]),
                )),
                const SizedBox(height: 8),
              ],
              if (rows.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No matching active states returned.'))),
              const SizedBox(height: 8),
              Text('State deletion/flush remains disabled in v0.3 because it can interrupt active user traffic immediately.', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}
