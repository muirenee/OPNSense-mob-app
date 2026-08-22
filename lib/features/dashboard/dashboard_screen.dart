import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../profiles/firewall_profile.dart';
import '../services/services_screen.dart';
import '../system/firmware_screen.dart';
import 'dashboard_models.dart';
import 'dashboard_repository.dart';
import 'dashboard_traffic_card.dart';
import 'gateway_details_screen.dart';
import 'memory_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.profile,
    required this.credentials,
    required this.onSelectMainTab,
  });

  final FirewallProfile profile;
  final FirewallCredentials credentials;
  final ValueChanged<int> onSelectMainTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DashboardRepository _repository;
  late Future<DashboardSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _buildRepository();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      _buildRepository();
    }
  }

  void _buildRepository() {
    _repository = DashboardRepository(
      OpnSenseApiClient(
        profile: widget.profile,
        credentials: widget.credentials,
      ),
    );
    _future = _repository.load();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.load());
    await _future;
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openGateways(List<GatewaySummary> gateways, {bool offlineOnly = false}) {
    _open(
      GatewayDetailsScreen(
        profile: widget.profile,
        credentials: widget.credentials,
        initialGateways: gateways,
        offlineOnly: offlineOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error, onRetry: _refresh);
        }

        final data = snapshot.data!;
        final system = _SystemSummary.from(data.systemInformation);
        final memory = _MemorySummary.from(data.memory);
        final disk = _DiskSummary.from(data.disk);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _HeroHeader(profile: widget.profile),
              const SizedBox(height: 16),
              _SystemCard(
                summary: system,
                onUpdates: () => _open(
                  FirmwareScreen(
                    profile: widget.profile,
                    credentials: widget.credentials,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 520;
                  final memoryCard = _ResourceCard(
                    title: 'Memory',
                    icon: Icons.memory_outlined,
                    percent: memory.percent,
                    headline: memory.headline,
                    detail: memory.detail,
                    onTap: () => _open(
                      MemoryDetailsScreen(resources: data.memory),
                    ),
                  );
                  final diskCard = _ResourceCard(
                    title: 'Disk',
                    icon: Icons.storage_outlined,
                    percent: disk.percent,
                    headline: disk.headline,
                    detail: disk.detail,
                    onTap: () => _open(
                      _DiskDetailsScreen(disk: data.disk, summary: disk),
                    ),
                  );

                  if (!wide) {
                    return Column(
                      children: [
                        memoryCard,
                        const SizedBox(height: 10),
                        diskCard,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: memoryCard),
                      const SizedBox(width: 10),
                      Expanded(child: diskCard),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              _GatewaysCard(
                gateways: data.gateways,
                onTapAll: () => _openGateways(data.gateways),
                onTapOffline: () =>
                    _openGateways(data.gateways, offlineOnly: true),
              ),
              const SizedBox(height: 10),
              DashboardTrafficCard(
                profile: widget.profile,
                credentials: widget.credentials,
                interfaces: data.interfaces,
              ),
              const SizedBox(height: 10),
              _InterfacesCard(
                interfaces: data.interfaces,
                onTap: () => widget.onSelectMainTab(2),
              ),
              const SizedBox(height: 18),
              const _SectionTitle(
                title: 'Quick actions',
                subtitle: 'Frequently used Sentinel tools',
              ),
              const SizedBox(height: 9),
              _QuickActions(
                onFirewall: () => widget.onSelectMainTab(1),
                onNetwork: () => widget.onSelectMainTab(2),
                onVpn: () => widget.onSelectMainTab(3),
                onServices: () => _open(
                  ServicesScreen(
                    profile: widget.profile,
                    credentials: widget.credentials,
                  ),
                ),
                onDiagnostics: () => _open(
                  DiagnosticsScreen(
                    profile: widget.profile,
                    credentials: widget.credentials,
                  ),
                ),
                onUpdates: () => _open(
                  FirmwareScreen(
                    profile: widget.profile,
                    credentials: widget.credentials,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.profile});

  final FirewallProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.shield_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.35,
                    ),
              ),
              const SizedBox(height: 1),
              Text(
                profile.baseUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SystemCard extends StatelessWidget {
  const _SystemCard({required this.summary, required this.onUpdates});

  final _SystemSummary summary;
  final VoidCallback onUpdates;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _IconBadge(icon: Icons.dns_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'System',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const _StatusPill(text: 'Connected', positive: true),
              ],
            ),
            const SizedBox(height: 14),
            _InfoRow(label: 'Name', value: summary.name),
            _InfoRow(label: 'Version', value: summary.version),
            if (summary.uptime.isNotEmpty)
              _InfoRow(label: 'Uptime', value: summary.uptime),
            const SizedBox(height: 2),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onUpdates,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        'Updates',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.system_update_alt,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Check for updates',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.title,
    required this.icon,
    required this.percent,
    required this.headline,
    required this.detail,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final double? percent;
  final String headline;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconBadge(icon: icon),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 19),
                ],
              ),
              const SizedBox(height: 14),
              if (percent != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${percent!.round()}%',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(width: 7),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        'used',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (percent! / 100).clamp(0, 1),
                    minHeight: 7,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GatewaysCard extends StatelessWidget {
  const _GatewaysCard({
    required this.gateways,
    required this.onTapAll,
    required this.onTapOffline,
  });

  final List<GatewaySummary> gateways;
  final VoidCallback onTapAll;
  final VoidCallback onTapOffline;

  @override
  Widget build(BuildContext context) {
    final offline = gateways.where((gateway) => gateway.isOffline).length;
    final online = gateways.where((gateway) => gateway.isOnline).length;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTapAll,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _IconBadge(icon: Icons.alt_route),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gateways',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (gateways.isNotEmpty)
                    _StatusPill(
                      text: offline == 0 ? 'All online' : '$offline offline',
                      positive: offline == 0,
                      warning: offline > 0,
                    ),
                  const SizedBox(width: 3),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 13),
              if (gateways.isEmpty)
                Text(
                  'Gateway status is unavailable for this API user.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _GatewayMetric(
                        label: 'Total gateways',
                        value: gateways.length,
                        icon: Icons.router_outlined,
                        onTap: onTapAll,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _GatewayMetric(
                        label: 'Offline',
                        value: offline,
                        icon: Icons.cloud_off_outlined,
                        warning: offline > 0,
                        onTap: onTapOffline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.circle, size: 9, color: Colors.green),
                    const SizedBox(width: 6),
                    Text('$online online'),
                    const SizedBox(width: 14),
                    Icon(
                      Icons.circle,
                      size: 9,
                      color: offline > 0 ? scheme.error : scheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Text('$offline offline'),
                    const Spacer(),
                    Text(
                      'View details',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GatewayMetric extends StatelessWidget {
  const _GatewayMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.warning = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final VoidCallback onTap;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warning ? scheme.error : scheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: warning ? scheme.error : null,
                        ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterfacesCard extends StatelessWidget {
  const _InterfacesCard({required this.interfaces, required this.onTap});

  final List<InterfaceSummary> interfaces;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final up = interfaces.where((item) => item.isUp).length;
    final visible = interfaces.take(4).toList();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _IconBadge(icon: Icons.hub_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Interfaces',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  _StatusPill(
                    text: '$up/${interfaces.length} up',
                    positive: interfaces.isNotEmpty && up == interfaces.length,
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              if (interfaces.isEmpty)
                const Text('No interface records returned by this API user.')
              else
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) const Divider(height: 16),
                  _InterfaceRow(interface: visible[i]),
                ],
              if (interfaces.length > 4) ...[
                const SizedBox(height: 7),
                Text(
                  '+ ${interfaces.length - 4} more interfaces',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InterfaceRow extends StatelessWidget {
  const _InterfaceRow({required this.interface});

  final InterfaceSummary interface;

  @override
  Widget build(BuildContext context) {
    final color = interface.isUp
        ? Colors.green
        : Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  interface.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  [interface.identifier, ...interface.addresses]
                      .where((item) => item.isNotEmpty)
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          _StatusPill(text: interface.status, positive: interface.isUp),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onFirewall,
    required this.onNetwork,
    required this.onVpn,
    required this.onServices,
    required this.onDiagnostics,
    required this.onUpdates,
  });

  final VoidCallback onFirewall;
  final VoidCallback onNetwork;
  final VoidCallback onVpn;
  final VoidCallback onServices;
  final VoidCallback onDiagnostics;
  final VoidCallback onUpdates;

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Firewall', Icons.security_outlined, onFirewall),
      ('Network', Icons.hub_outlined, onNetwork),
      ('VPN', Icons.vpn_lock_outlined, onVpn),
      ('Services', Icons.miscellaneous_services_outlined, onServices),
      ('Diagnostics', Icons.troubleshoot_outlined, onDiagnostics),
      ('Updates', Icons.system_update_alt, onUpdates),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 720
            ? 6
            : constraints.maxWidth >= 480
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: count == 2 ? 1.72 : 1.48,
          ),
          itemBuilder: (context, index) {
            final item = actions[index];
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: item.$3,
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.$2,
                        size: 22,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 9),
                      Text(
                        item.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 19,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

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
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.positive,
    this.warning = false,
  });

  final String text;
  final bool positive;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warning
        ? scheme.error
        : positive
            ? Colors.green
            : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _DiskDetailsScreen extends StatelessWidget {
  const _DiskDetailsScreen({required this.disk, required this.summary});

  final Map<String, dynamic> disk;
  final _DiskSummary summary;

  @override
  Widget build(BuildContext context) {
    final devices = _diskDevices(disk);
    return Scaffold(
      appBar: AppBar(title: const Text('Disk storage')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.headline,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (summary.detail.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(summary.detail),
                  ],
                  if (summary.percent != null) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (summary.percent! / 100).clamp(0, 1),
                      minHeight: 8,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final device in devices) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: Text(
                  _text(device['mountpoint']).isEmpty
                      ? _text(device['device'])
                      : _text(device['mountpoint']),
                ),
                subtitle: Text(
                  [
                    if (_text(device['device']).isNotEmpty)
                      _text(device['device']),
                    if (_text(device['type']).isNotEmpty) _text(device['type']),
                    if (_text(device['used']).isNotEmpty)
                      'Used ${_text(device['used'])}',
                    if (_text(device['available']).isNotEmpty)
                      'Free ${_text(device['available'])}',
                  ].join(' · '),
                ),
                trailing: _number(device['used_pct']) == null
                    ? null
                    : Text(
                        '${_number(device['used_pct'])!.round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

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
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Dashboard unavailable',
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

class _SystemSummary {
  const _SystemSummary({
    required this.name,
    required this.version,
    required this.uptime,
  });

  final String name;
  final String version;
  final String uptime;

  factory _SystemSummary.from(Map<String, dynamic> raw) {
    final name = _firstText(raw, const ['hostname', 'name', 'host']) ?? 'Firewall';
    final versionValue = raw['versions'] ??
        raw['product_version'] ??
        raw['version'] ??
        raw['platform'];
    final version = _shortValue(versionValue);
    final uptime = _firstText(raw, const ['uptime', 'uptime_string']) ?? '';
    return _SystemSummary(
      name: name,
      version: version.isEmpty ? 'Version information available' : version,
      uptime: uptime,
    );
  }
}

class _MemorySummary {
  const _MemorySummary({
    required this.percent,
    required this.headline,
    required this.detail,
  });

  final double? percent;
  final String headline;
  final String detail;

  factory _MemorySummary.from(Map<String, dynamic> raw) {
    final memory = _map(raw['memory']);
    final total = _number(memory['total']);
    final used = _number(memory['used']);
    final percent = total != null && total > 0 && used != null
        ? ((used / total) * 100).clamp(0, 100).toDouble()
        : null;
    final totalMb = _text(memory['total_frmt']);
    final usedMb = _text(memory['used_frmt']);
    return _MemorySummary(
      percent: percent,
      headline: percent == null
          ? 'Memory resource information'
          : '${percent.round()}% of memory in use',
      detail: [
        if (usedMb.isNotEmpty) 'Used $usedMb MB',
        if (totalMb.isNotEmpty) 'Total $totalMb MB',
      ].join(' · '),
    );
  }
}

class _DiskSummary {
  const _DiskSummary({
    required this.percent,
    required this.headline,
    required this.detail,
  });

  final double? percent;
  final String headline;
  final String detail;

  factory _DiskSummary.from(Map<String, dynamic> raw) {
    final root = _rootDisk(raw);
    final percent = _number(root?['used_pct']);
    final used = _text(root?['used']);
    final available = _text(root?['available']);
    return _DiskSummary(
      percent: percent,
      headline: percent == null
          ? 'Disk resource information'
          : '${percent.round()}% used on /',
      detail: [
        if (used.isNotEmpty) 'Used $used',
        if (available.isNotEmpty) 'Free $available',
      ].join(' · '),
    );
  }
}

String? _firstText(Map<String, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    final value = raw[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return _shortValue(value);
    }
  }
  return null;
}

String _shortValue(dynamic value) {
  if (value == null) return '';
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .take(2)
        .join(' · ');
  }
  if (value is Map) {
    return value.values
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .take(2)
        .join(' · ');
  }
  final text = value.toString().trim();
  return text.length > 120 ? '${text.substring(0, 117)}…' : text;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

double? _number(dynamic value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString().replaceAll('%', '').trim());
}

String _text(dynamic value) => value?.toString().trim() ?? '';

Map<String, dynamic>? _rootDisk(Map<String, dynamic> raw) {
  final devices = raw['devices'];
  if (devices is List) {
    for (final item in devices) {
      if (item is Map && item['mountpoint']?.toString() == '/') {
        return Map<String, dynamic>.from(item);
      }
    }
    for (final item in devices) {
      if (item is Map) return Map<String, dynamic>.from(item);
    }
  }
  return null;
}

List<Map<String, dynamic>> _diskDevices(Map<String, dynamic> raw) {
  final devices = raw['devices'];
  if (devices is! List) return const <Map<String, dynamic>>[];
  return devices
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
