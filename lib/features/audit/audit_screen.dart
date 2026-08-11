import 'package:flutter/material.dart';

import 'audit_repository.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key, required this.profileId});

  final String profileId;

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  late final AuditRepository _repository;
  late Future<List<AuditEntry>> _future;

  @override
  void initState() {
    super.initState();
    _repository = AuditRepository(profileId: widget.profileId);
    _future = _repository.load();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App audit trail'),
        actions: [
          IconButton(
            tooltip: 'Clear audit trail',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear audit trail?'),
                      content: const Text(
                        'This only clears the local app audit history for this firewall profile.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ) ??
                  false;
              if (!confirmed) return;
              await _repository.clear();
              await _refresh();
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<AuditEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const <AuditEntry>[];
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No app-initiated changes have been recorded yet.'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      entry.result.toLowerCase() == 'success'
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                    ),
                    title: Text('${entry.action} · ${entry.target}'),
                    subtitle: Text(
                      '${entry.timestamp.toLocal()}\n${entry.result}${entry.details.isEmpty ? '' : ' · ${entry.details}'}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
