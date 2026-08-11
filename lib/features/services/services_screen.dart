import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../audit/audit_repository.dart';
import '../profiles/firewall_profile.dart';
import 'services_models.dart';
import 'services_repository.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({
    super.key,
    required this.profile,
    required this.credentials,
  });

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late final ServicesRepository _repository;
  late final AuditRepository _audit;
  late Future<List<ServiceSummary>> _future;
  String _query = '';
  String? _busyService;

  @override
  void initState() {
    super.initState();
    _repository = ServicesRepository(
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
    );
    _audit = AuditRepository(profileId: widget.profile.id);
    _future = _repository.load();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.load());
    await _future;
  }

  Future<void> _perform(ServiceSummary service, ServiceAction action) async {
    final verb = switch (action) {
      ServiceAction.start => 'Start',
      ServiceAction.stop => 'Stop',
      ServiceAction.restart => 'Restart',
    };
    final disruptive = action != ServiceAction.start;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$verb service?'),
            content: Text(
              disruptive
                  ? '$verb ${service.description.isEmpty ? service.name : service.description}? Active connections using this service may be interrupted.'
                  : '$verb ${service.description.isEmpty ? service.name : service.description}?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(verb)),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _busyService = service.name);
    try {
      await _repository.perform(service, action);
      try {
        await _audit.record(action: 'Service $verb', target: service.name, result: 'success');
      } catch (_) {
        // The service action succeeded; audit persistence must not change that result.
      }
      await _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$verb command sent to ${service.name}.')));
    } catch (error) {
      try {
        await _audit.record(action: 'Service $verb', target: service.name, result: 'failed', details: error.toString());
      } catch (_) {
        // Preserve the original API failure for the user.
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$verb failed: $error')));
    } finally {
      if (mounted) setState(() => _busyService = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ServicesError(error: snapshot.error, onRetry: _refresh);
        }

        final services = snapshot.data ?? const <ServiceSummary>[];
        final normalized = _query.trim().toLowerCase();
        final filtered = normalized.isEmpty
            ? services
            : services.where((item) =>
                item.name.toLowerCase().contains(normalized) ||
                item.description.toLowerCase().contains(normalized) ||
                item.status.toLowerCase().contains(normalized)).toList();
        final running = services.where((item) => item.isRunning).length;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text('Services', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('$running running · ${services.length - running} stopped/other'),
              const SizedBox(height: 14),
              TextField(
                decoration: const InputDecoration(hintText: 'Search services', prefixIcon: Icon(Icons.search)),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Card(
                child: filtered.isEmpty
                    ? const Padding(padding: EdgeInsets.all(20), child: Text('No matching services returned.'))
                    : Column(children: [
                        for (var i = 0; i < filtered.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _ServiceTile(
                            service: filtered[i],
                            busy: _busyService == filtered[i].name,
                            onAction: (action) => _perform(filtered[i], action),
                          ),
                        ],
                      ]),
              ),
              const SizedBox(height: 12),
              Text('Service changes require confirmation and are written to the local app audit trail.', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.busy, required this.onAction});

  final ServiceSummary service;
  final bool busy;
  final ValueChanged<ServiceAction> onAction;

  @override
  Widget build(BuildContext context) {
    final color = service.isRunning ? Colors.green : Theme.of(context).colorScheme.outline;
    return ListTile(
      leading: busy
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.circle, size: 12, color: color),
      title: Text(service.description.isEmpty ? service.name : service.description, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(service.description.isEmpty
          ? (service.status.isEmpty ? 'Unknown status' : service.status)
          : '${service.name} · ${service.status.isEmpty ? 'Unknown status' : service.status}'),
      trailing: PopupMenuButton<ServiceAction>(
        enabled: !busy,
        onSelected: onAction,
        itemBuilder: (context) => [
          if (!service.isRunning) const PopupMenuItem(value: ServiceAction.start, child: Text('Start')),
          if (service.isRunning) const PopupMenuItem(value: ServiceAction.restart, child: Text('Restart')),
          if (service.isRunning) const PopupMenuItem(value: ServiceAction.stop, child: Text('Stop')),
        ],
      ),
    );
  }
}

class _ServicesError extends StatelessWidget {
  const _ServicesError({required this.error, required this.onRetry});
  final Object? error;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.miscellaneous_services_outlined, size: 48, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 12),
        Text('Services unavailable', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(error.toString(), textAlign: TextAlign.center),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: () => onRetry(), icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ]),
    ));
  }
}
