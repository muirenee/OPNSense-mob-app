import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/opnsense_api_client.dart';
import '../../audit/audit_repository.dart';
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
  late final AuditRepository _audit;
  late Future<List<FirewallAliasSummary>> _future;
  final _search = TextEditingController();
  Timer? _debounce;
  String? _busyUuid;

  @override
  void initState() {
    super.initState();
    _repository = AliasRepository(OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials));
    _audit = AuditRepository(profileId: widget.profile.id);
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

  Future<void> _toggle(FirewallAliasSummary alias) async {
    final enabled = !alias.enabled;
    final verb = enabled ? 'Enable' : 'Disable';
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$verb alias?'),
            content: Text('$verb ${alias.name}? Firewall rules using this alias may be affected.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(verb)),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    setState(() => _busyUuid = alias.uuid);
    try {
      await _repository.setEnabled(alias, enabled);
      await _audit.record(action: '$verb alias', target: alias.name, result: 'success');
      await _refresh();
    } catch (error) {
      await _audit.record(action: '$verb alias', target: alias.name, result: 'failed', details: error.toString());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alias change failed: $error')));
    } finally {
      if (mounted) setState(() => _busyUuid = null);
    }
  }

  Future<void> _delete(FirewallAliasSummary alias) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete alias?'),
            content: Text('Delete ${alias.name}? References to this alias may stop working. This cannot be undone from the app.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    setState(() => _busyUuid = alias.uuid);
    try {
      await _repository.delete(alias);
      await _audit.record(action: 'Delete alias', target: alias.name, result: 'success');
      await _refresh();
    } catch (error) {
      await _audit.record(action: 'Delete alias', target: alias.name, result: 'failed', details: error.toString());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alias delete failed: $error')));
    } finally {
      if (mounted) setState(() => _busyUuid = null);
    }
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Aliases', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
                  Chip(label: Text('${aliases.length} items')),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: _search, onChanged: _onSearch, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search aliases')),
              const SizedBox(height: 12),
              for (final alias in aliases) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Icon(alias.enabled ? Icons.label_outline : Icons.label_off_outlined, color: alias.enabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(alias.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 3),
                              Text([alias.type, alias.content].where((item) => item.isNotEmpty).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                              if (alias.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(alias.description, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              ],
                            ],
                          ),
                        ),
                        if (_busyUuid == alias.uuid)
                          const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                        else
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'toggle') _toggle(alias);
                              if (value == 'delete') _delete(alias);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'toggle', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(alias.enabled ? Icons.toggle_off_outlined : Icons.toggle_on_outlined), title: Text(alias.enabled ? 'Disable' : 'Enable'))),
                              const PopupMenuItem(value: 'delete', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline), title: Text('Delete'))),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (aliases.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No matching aliases returned.'))),
            ],
          ),
        );
      },
    );
  }
}
