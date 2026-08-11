import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../profiles/firewall_profile.dart';
import 'firewall_log_models.dart';
import 'firewall_log_repository.dart';

class FirewallLogScreen extends StatefulWidget {
  const FirewallLogScreen({
    super.key,
    required this.profile,
    required this.credentials,
  });

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<FirewallLogScreen> createState() => _FirewallLogScreenState();
}

class _FirewallLogScreenState extends State<FirewallLogScreen> {
  late final FirewallLogRepository _repository;
  List<FirewallLogEntry>? _entries;
  Object? _error;
  Timer? _timer;
  String _filter = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = FirewallLogRepository(
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
    );
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final entries = await _repository.load();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (_entries == null) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _entries == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _entries == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text('Firewall log unavailable',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final all = _entries ?? const <FirewallLogEntry>[];
    final q = _filter.trim().toLowerCase();
    final entries = q.isEmpty
        ? all
        : all.where((entry) {
            return [
              entry.action,
              entry.interfaceName,
              entry.protocol,
              entry.source,
              entry.destination,
              entry.sourcePort,
              entry.destinationPort,
              entry.label,
              entry.ruleId,
            ].any((value) => value.toLowerCase().contains(q));
          }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Live firewall log',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const _LivePill(),
            ],
          ),
          const SizedBox(height: 4),
          Text('${all.length} recent entries · refreshes every 3 seconds'),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Filter IP, port, interface, action…',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No matching firewall log entries.'),
              ),
            )
          else
            for (final entry in entries) ...[
              _LogCard(entry: entry),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.entry});

  final FirewallLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final action = entry.action.toLowerCase();
    final blocked = action.contains('block') || action.contains('reject');
    final icon = blocked ? Icons.block : Icons.check_circle_outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${entry.action.isEmpty ? 'Unknown' : entry.action} · ${entry.protocol.isEmpty ? 'IP' : entry.protocol}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (entry.interfaceName.isNotEmpty)
                        Text(entry.interfaceName,
                            style: Theme.of(context).textTheme.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text('${_endpoint(entry.source, entry.sourcePort)}  →  ${_endpoint(entry.destination, entry.destinationPort)}'),
                  if (entry.label.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(entry.label),
                  ],
                  if (entry.timestamp.isNotEmpty || entry.ruleId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (entry.timestamp.isNotEmpty) entry.timestamp,
                        if (entry.ruleId.isNotEmpty) 'Rule ${entry.ruleId}',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '3s LIVE',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

String _endpoint(String address, String port) {
  final host = address.trim().isEmpty ? 'any' : address.trim();
  return port.trim().isEmpty ? host : '$host:${port.trim()}';
}
