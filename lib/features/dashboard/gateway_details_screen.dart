import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../profiles/firewall_profile.dart';
import 'dashboard_models.dart';
import 'dashboard_repository.dart';

class GatewayDetailsScreen extends StatefulWidget {
  const GatewayDetailsScreen({
    super.key,
    required this.profile,
    required this.credentials,
    required this.initialGateways,
    this.offlineOnly = false,
  });

  final FirewallProfile profile;
  final FirewallCredentials credentials;
  final List<GatewaySummary> initialGateways;
  final bool offlineOnly;

  @override
  State<GatewayDetailsScreen> createState() => _GatewayDetailsScreenState();
}

class _GatewayDetailsScreenState extends State<GatewayDetailsScreen> {
  late DashboardRepository _repository;
  late List<GatewaySummary> _gateways;
  late bool _offlineOnly;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _gateways = List<GatewaySummary>.from(widget.initialGateways);
    _offlineOnly = widget.offlineOnly;
    _repository = DashboardRepository(
      OpnSenseApiClient(
        profile: widget.profile,
        credentials: widget.credentials,
      ),
    );
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final snapshot = await _repository.load();
      if (!mounted) return;
      setState(() => _gateways = snapshot.gateways);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline = _gateways.where((gateway) => gateway.isOffline).length;
    final visible = _offlineOnly
        ? _gateways.where((gateway) => gateway.isOffline).toList()
        : _gateways;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gateways'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Total',
                    value: _gateways.length.toString(),
                    icon: Icons.alt_route,
                    selected: !_offlineOnly,
                    onTap: () => setState(() => _offlineOnly = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryTile(
                    label: 'Offline',
                    value: offline.toString(),
                    icon: Icons.cloud_off_outlined,
                    selected: _offlineOnly,
                    warning: offline > 0,
                    onTap: () => setState(() => _offlineOnly = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_gateways.isEmpty)
              const _EmptyState(
                message:
                    'No gateway status records were returned. Check API permissions or gateway monitoring configuration.',
              )
            else if (visible.isEmpty)
              const _EmptyState(message: 'No offline gateways. Everything looks healthy.')
            else
              for (final gateway in visible) ...[
                _GatewayCard(gateway: gateway),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.warning = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final bool warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = warning ? scheme.error : scheme.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: warning ? scheme.error : null,
                          ),
                    ),
                    Text(
                      label,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, size: 18, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _GatewayCard extends StatelessWidget {
  const _GatewayCard({required this.gateway});

  final GatewaySummary gateway;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = gateway.isOffline
        ? scheme.error
        : gateway.isOnline
            ? Colors.green
            : scheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    gateway.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    gateway.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailRow(label: 'Interface', value: gateway.interfaceName),
            _DetailRow(label: 'Gateway IP', value: gateway.gateway),
            _DetailRow(label: 'Monitor IP', value: gateway.monitor),
            _DetailRow(label: 'RTT / delay', value: gateway.delay),
            _DetailRow(label: 'Packet loss', value: gateway.loss),
            if (gateway.description.isNotEmpty)
              _DetailRow(label: 'Description', value: gateway.description),
          ],
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.alt_route,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
