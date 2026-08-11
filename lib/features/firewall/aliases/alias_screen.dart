import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/opnsense_api_client.dart';
import '../../profiles/firewall_profile.dart';
import 'alias_models.dart';
import 'alias_repository.dart';

class AliasScreen extends StatefulWidget {
  const AliasScreen({super.key, required this.profile, required this.credentials});
  final FirewallProfile profile;
  final FirewallCredentials credentials;
  @override
  State<AliasScreen> createState() => _AliasScreenState();
}

class _AliasScreenState extends State<AliasScreen> {
  late final AliasRepository _repository;
  late Future<List<FirewallAliasSummary>> _future;
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _repository = AliasRepository(OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials));
    _future = _repository.load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _future = _repository.load(search: value));
    });
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.load(search: _search.text));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FirewallAliasSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Aliases unavailable\n${snapshot.error}', textAlign: TextAlign.center)));
        final aliases = snapshot.data ?? const <FirewallAliasSummary>[];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text('Aliases', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(controller: _search, onChanged: _onSearch, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search aliases')),
              const SizedBox(height: 12),
              for (final alias in aliases) ...[
                Card(child: ListTile(
                  leading: Icon(alias.enabled ? Icons.label_outline : Icons.label_off_outlined),
                  title: Text(alias.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    alias.type,
                    alias.content,
                    alias.description,
                    alias.enabled ? '' : 'disabled',
                  ].where((item) => item.isNotEmpty).join('\n')),
                  isThreeLine: alias.content.isNotEmpty || alias.description.isNotEmpty,
                )),
                const SizedBox(height: 8),
              ],
              if (aliases.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No matching aliases returned.'))),
              const SizedBox(height: 8),
              Text('v0.3 keeps alias editing read-only. Rule/service writes are introduced first because they can be guarded and audited more predictably.', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}
