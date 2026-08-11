import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../audit/audit_repository.dart';
import '../profiles/firewall_profile.dart';
import 'services_models.dart';
import 'services_repository.dart';

enum _ServiceFilter { all, running, stopped, other }

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
  final _searchController = TextEditingController();
  _ServiceFilter _filter = _ServiceFilter.all;
  String _query = '';
  String? _busyService;

  @override
  void initState() {
    super.initState();
    _repository = ServicesRepository(
      OpnSenseApiClient(
        profile: widget.profile,
        credentials: widget.credentials,
      ),
    );
    _audit = AuditRepository(profileId: widget.profile.id);
    _future = _repository.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                  ? '$verb ${service.displayName}? Active connections using this service may be interrupted.'
                  : '$verb ${service.displayName}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(verb),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _busyService = service.name);
    try {
      await _repository.perform(service, action);
      try {
        await _audit.record(
          action: 'Service $verb',
          target: service.name,
          result: 'success',
        );
      } catch (_) {
        // The service action succeeded; audit persistence must not change it.
      }
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$verb command sent to ${service.displayName}.')),
        );
      }
    } catch (error) {
      try {
        await _audit.record(
          action: 'Service $verb',
          target: service.name,
          result: 'failed',
          details: error.toString(),
        );
      } catch (_) {
        // Preserve the original API failure for the user.
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$verb failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyService = null);
    }
  }

  void _showDetails(ServiceSummary service) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ServiceIcon(service: service, busy: false, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.displayName,
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            service.name,
                            style: TextStyle(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(service: service),
                  ],
                ),
                const SizedBox(height: 20),
                _DetailRow(label: 'Service', value: service.name),
                _DetailRow(label: 'Status', value: service.statusLabel),
                if (service.id.isNotEmpty)
                  _DetailRow(label: 'Instance', value: service.id),
                if (service.description.isNotEmpty)
                  _DetailRow(label: 'Description', value: service.description),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (!service.isRunning)
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _perform(service, ServiceAction.start);
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start'),
                      ),
                    if (service.isRunning)
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _perform(service, ServiceAction.restart);
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Restart'),
                      ),
                    if (service.isRunning)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _perform(service, ServiceAction.stop);
                        },
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Stop'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<ServiceSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ServicesError(error: snapshot.error, onRetry: _refresh);
          }

          final services = snapshot.data ?? const <ServiceSummary>[];
          final running = services
              .where((item) => item.statusKind == ServiceStatusKind.running)
              .length;
          final stopped = services
              .where((item) => item.statusKind == ServiceStatusKind.stopped)
              .length;
          final other = services.length - running - stopped;
          final filtered = _applyFilters(services);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _HealthCard(
                  total: services.length,
                  running: running,
                  stopped: stopped,
                  other: other,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search services',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                _FilterBar(
                  selected: _filter,
                  total: services.length,
                  running: running,
                  stopped: stopped,
                  other: other,
                  onChanged: (value) => setState(() => _filter = value),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Service list',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${filtered.length} shown',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  const _EmptyState()
                else
                  for (final service in filtered) ...[
                    _ServiceCard(
                      service: service,
                      busy: _busyService == service.name,
                      onTap: () => _showDetails(service),
                      onAction: (action) => _perform(service, action),
                    ),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 4),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Start, stop and restart actions require confirmation and are recorded in the Sentinel audit trail.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<ServiceSummary> _applyFilters(List<ServiceSummary> services) {
    final normalized = _query.trim().toLowerCase();
    return services.where((item) {
      final matchesStatus = switch (_filter) {
        _ServiceFilter.all => true,
        _ServiceFilter.running =>
          item.statusKind == ServiceStatusKind.running,
        _ServiceFilter.stopped =>
          item.statusKind == ServiceStatusKind.stopped,
        _ServiceFilter.other => item.statusKind == ServiceStatusKind.other,
      };
      if (!matchesStatus) return false;
      if (normalized.isEmpty) return true;
      return item.name.toLowerCase().contains(normalized) ||
          item.description.toLowerCase().contains(normalized) ||
          item.statusLabel.toLowerCase().contains(normalized);
    }).toList();
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.total,
    required this.running,
    required this.stopped,
    required this.other,
  });

  final int total;
  final int running;
  final int stopped;
  final int other;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.miscellaneous_services_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service health',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '$total services reported by this firewall',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SummaryStat(
                  icon: Icons.check_circle_outline,
                  label: 'Running',
                  value: running,
                  kind: ServiceStatusKind.running,
                ),
                _SummaryStat(
                  icon: Icons.stop_circle_outlined,
                  label: 'Stopped',
                  value: stopped,
                  kind: ServiceStatusKind.stopped,
                ),
                if (other > 0)
                  _SummaryStat(
                    icon: Icons.help_outline,
                    label: 'Other',
                    value: other,
                    kind: ServiceStatusKind.other,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.kind,
  });

  final IconData icon;
  final String label;
  final int value;
  final ServiceStatusKind kind;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, kind);
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 5),
          Text(label),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.total,
    required this.running,
    required this.stopped,
    required this.other,
    required this.onChanged,
  });

  final _ServiceFilter selected;
  final int total;
  final int running;
  final int stopped;
  final int other;
  final ValueChanged<_ServiceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(_ServiceFilter.all, 'All', total),
          const SizedBox(width: 8),
          _chip(_ServiceFilter.running, 'Running', running),
          const SizedBox(width: 8),
          _chip(_ServiceFilter.stopped, 'Stopped', stopped),
          if (other > 0) ...[
            const SizedBox(width: 8),
            _chip(_ServiceFilter.other, 'Other', other),
          ],
        ],
      ),
    );
  }

  Widget _chip(_ServiceFilter value, String label, int count) {
    return ChoiceChip(
      selected: selected == value,
      onSelected: (_) => onChanged(value),
      label: Text('$label $count'),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.busy,
    required this.onTap,
    required this.onAction,
  });

  final ServiceSummary service;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<ServiceAction> onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            children: [
              _ServiceIcon(service: service, busy: busy),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.id.isEmpty
                          ? service.name
                          : '${service.name} · ${service.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusPill(service: service),
                  ],
                ),
              ),
              PopupMenuButton<ServiceAction>(
                enabled: !busy,
                tooltip: 'Service actions',
                onSelected: onAction,
                itemBuilder: (context) => [
                  if (!service.isRunning)
                    const PopupMenuItem(
                      value: ServiceAction.start,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.play_arrow),
                        title: Text('Start'),
                      ),
                    ),
                  if (service.isRunning)
                    const PopupMenuItem(
                      value: ServiceAction.restart,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.restart_alt),
                        title: Text('Restart'),
                      ),
                    ),
                  if (service.isRunning)
                    const PopupMenuItem(
                      value: ServiceAction.stop,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.stop_circle_outlined),
                        title: Text('Stop'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({
    required this.service,
    required this.busy,
    this.size = 42,
  });

  final ServiceSummary service;
  final bool busy;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, service.statusKind);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(size * .30),
      ),
      alignment: Alignment.center,
      child: busy
          ? SizedBox(
              width: size * .46,
              height: size * .46,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          : Icon(
              service.isRunning
                  ? Icons.power_settings_new
                  : service.isStopped
                      ? Icons.power_off_outlined
                      : Icons.settings_outlined,
              size: size * .52,
              color: color,
            ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.service});

  final ServiceSummary service;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, service.statusKind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        service.statusLabel,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 38,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'No matching services',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Change the status filter or search term.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.miscellaneous_services_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Services unavailable',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
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

Color _statusColor(BuildContext context, ServiceStatusKind kind) {
  final colors = Theme.of(context).colorScheme;
  return switch (kind) {
    ServiceStatusKind.running => colors.primary,
    ServiceStatusKind.stopped => colors.error,
    ServiceStatusKind.other => colors.tertiary,
  };
}
