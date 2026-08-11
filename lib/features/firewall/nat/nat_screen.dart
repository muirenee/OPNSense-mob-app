import 'package:flutter/material.dart';

import '../../../core/api/opnsense_api_client.dart';
import '../../profiles/firewall_profile.dart';
import 'nat_models.dart';
import 'nat_repository.dart';

class NatScreen extends StatefulWidget {
  const NatScreen({super.key, required this.profile, required this.credentials});
  final FirewallProfile profile;
  final FirewallCredentials credentials;
  @override
  State<NatScreen> createState() => _NatScreenState();
}

class _NatScreenState extends State<NatScreen> {
  late final NatRepository _repository;
  late Future<List<NatRuleSummary>> _portForwards;
  late Future<List<NatRuleSummary>> _outbound;

  @override
  void initState() {
    super.initState();
    _repository = NatRepository(OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials));
    _reload();
  }

  void _reload() {
    _portForwards = _repository.loadPortForwards();
    _outbound = _repository.loadOutbound();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait([_portForwards, _outbound]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        const Material(child: TabBar(tabs: [Tab(text: 'Port Forward'), Tab(text: 'Outbound')])),
        Expanded(child: TabBarView(children: [
          _NatList(future: _portForwards, onRefresh: _refresh, emptyText: 'No port-forward rules returned.'),
          _NatList(future: _outbound, onRefresh: _refresh, emptyText: 'No outbound NAT rules returned.'),
        ])),
      ]),
    );
  }
}

class _NatList extends StatelessWidget {
  const _NatList({required this.future, required this.onRefresh, required this.emptyText});
  final Future<List<NatRuleSummary>> future;
  final Future<void> Function() onRefresh;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NatRuleSummary>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('NAT view unavailable\n${snapshot.error}', textAlign: TextAlign.center)));
        final rules = snapshot.data ?? const <NatRuleSummary>[];
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              for (final rule in rules) ...[
                Card(child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(rule.description.isEmpty ? 'Unnamed NAT rule' : rule.description, style: const TextStyle(fontWeight: FontWeight.w800))),
                      Text(rule.enabled ? 'Enabled' : 'Disabled'),
                    ]),
                    const SizedBox(height: 8),
                    Text([rule.interfaceName, rule.protocol].where((e) => e.isNotEmpty).join(' · ')),
                    const SizedBox(height: 8),
                    Text('Source: ${_endpoint(rule.source, rule.sourcePort)}'),
                    Text('Destination: ${_endpoint(rule.destination, rule.destinationPort)}'),
                    if (rule.target.isNotEmpty || rule.targetPort.isNotEmpty) Text('Translation: ${_endpoint(rule.target, rule.targetPort)}'),
                  ]),
                )),
                const SizedBox(height: 8),
              ],
              if (rules.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(emptyText))),
              const SizedBox(height: 8),
              Text('NAT is read-only in v0.3. Editing will use the same rollback-safe transaction approach as firewall-rule changes.', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}

String _endpoint(String address, String port) {
  final a = address.isEmpty ? 'any' : address;
  return port.isEmpty ? a : '$a:$port';
}
