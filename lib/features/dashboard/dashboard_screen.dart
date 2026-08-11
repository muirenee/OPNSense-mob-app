import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../firewall/firewall_module_screen.dart';
import '../network/network_module_screen.dart';
import '../profiles/firewall_profile.dart';
import '../services/services_screen.dart';
import '../system/firmware_screen.dart';
import '../vpn/vpn_screen.dart';
import 'dashboard_models.dart';
import 'dashboard_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.profile,
    required this.credentials,
  });

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardRepository _repository;
  late Future<DashboardSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _repository = DashboardRepository(
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error, onRetry: _refresh);
        }
        final data = snapshot.data!;
        final system = _SystemSummary.from(data.systemInformation);
        final memory = _MetricSummary.memory(data.memory);
        final disk = _MetricSummary.disk(data.disk);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _HeroHeader(profile: widget.profile),
              const SizedBox(height: 18),
              _SystemCard(
                summary: system,
                onTap: () => _open(_JsonDetailScreen(title: 'System information', data: data.systemInformation)),
                onUpdates: () => _open(FirmwareScreen(profile: widget.profile, credentials: widget.credentials)),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 520;
                  final cards = [
                    _MetricCard(
                      title: 'Memory',
                      icon: Icons.memory_outlined,
                      summary: memory,
                      onTap: () => _open(_JsonDetailScreen(title: 'Memory details', data: data.memory)),
                    ),
                    _MetricCard(
                      title: 'Disk',
                      icon: Icons.storage_outlined,
                      summary: disk,
                      onTap: () => _open(_JsonDetailScreen(title: 'Disk details', data: data.disk)),
                    ),
                  ];
                  if (!wide) {
                    return Column(children: [cards[0], const SizedBox(height: 12), cards[1]]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])],
                  );
                },
              ),
              const SizedBox(height: 12),
              _InterfacesCard(
                interfaces: data.interfaces,
                onTap: () => _open(NetworkModuleScreen(profile: widget.profile, credentials: widget.credentials)),
              ),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Quick actions', subtitle: 'Jump directly to the most-used Sentinel tools'),
              const SizedBox(height: 10),
              _QuickActions(
                onFirewall: () => _open(FirewallModuleScreen(profile: widget.profile, credentials: widget.credentials)),
                onNetwork: () => _open(NetworkModuleScreen(profile: widget.profile, credentials: widget.credentials)),
                onVpn: () => _open(VpnScreen(profile: widget.profile, credentials: widget.credentials)),
                onServices: () => _open(ServicesScreen(profile: widget.profile, credentials: widget.credentials)),
                onDiagnostics: () => _open(DiagnosticsScreen(profile: widget.profile, credentials: widget.credentials)),
                onUpdates: () => _open(FirmwareScreen(profile: widget.profile, credentials: widget.credentials)),
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
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.4)),
              const SizedBox(height: 2),
              Text(profile.baseUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SystemCard extends StatelessWidget {
  const _SystemCard({required this.summary, required this.onTap, required this.onUpdates});
  final _SystemSummary summary;
  final VoidCallback onTap;
  final VoidCallback onUpdates;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconBadge(icon: Icons.dns_outlined),
                  const SizedBox(width: 10),
                  Expanded(child: Text('System', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 18),
              _InfoRow(label: 'Name', value: summary.name),
              _InfoRow(label: 'Version', value: summary.version),
              if (summary.uptime.isNotEmpty) _InfoRow(label: 'Uptime', value: summary.uptime),
              const SizedBox(height: 4),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onUpdates,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 92, child: Text('Updates', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.system_update_alt, size: 18, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 7),
                            Text('Check for updates', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
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
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.icon, required this.summary, required this.onTap});
  final String title;
  final IconData icon;
  final _MetricSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconBadge(icon: icon),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 18),
              if (summary.percent != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${summary.percent!.round()}%', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('used', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: (summary.percent! / 100).clamp(0, 1), minHeight: 8),
                ),
                const SizedBox(height: 12),
              ],
              Text(summary.primary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (summary.secondary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(summary.secondary, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _IconBadge(icon: Icons.hub_outlined),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Interfaces', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                  _StatusPill(text: '$up/${interfaces.length} up', positive: interfaces.isNotEmpty && up == interfaces.length),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 14),
              if (interfaces.isEmpty)
                const Text('No interface records returned by this API user.')
              else
                for (final interface in interfaces.take(5)) ...[
                  _InterfaceRow(interface: interface),
                  if (interface != interfaces.take(5).last) const Divider(height: 18),
                ],
              if (interfaces.length > 5) ...[
                const SizedBox(height: 8),
                Text('+ ${interfaces.length - 5} more interfaces', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
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
    final color = interface.isUp ? Colors.green : Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(interface.description, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  [interface.identifier, ...interface.addresses].where((e) => e.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
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
        final count = constraints.maxWidth >= 720 ? 6 : constraints.maxWidth >= 480 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: count == 2 ? 1.55 : 1.35,
          ),
          itemBuilder: (context, index) {
            final item = actions[index];
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: item.$3,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.$2, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 10),
                      Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
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
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 92, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.positive});
  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}

class _JsonDetailScreen extends StatelessWidget {
  const _JsonDetailScreen({required this.title, required this.data});
  final String title;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(pretty, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.45)),
            ),
          ),
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
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text('Dashboard unavailable', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: () => onRetry(), icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
}

class _SystemSummary {
  const _SystemSummary({required this.name, required this.version, required this.uptime});
  final String name;
  final String version;
  final String uptime;

  factory _SystemSummary.from(Map<String, dynamic> raw) {
    final name = _firstText(raw, const ['hostname', 'name', 'host']) ?? 'Firewall';
    final versionValue = raw['versions'] ?? raw['product_version'] ?? raw['version'] ?? raw['platform'];
    final version = _shortValue(versionValue);
    final uptime = _firstText(raw, const ['uptime', 'uptime_string']) ?? '';
    return _SystemSummary(name: name, version: version.isEmpty ? 'Version information available' : version, uptime: uptime);
  }
}

class _MetricSummary {
  const _MetricSummary({required this.percent, required this.primary, required this.secondary});
  final double? percent;
  final String primary;
  final String secondary;

  factory _MetricSummary.memory(Map<String, dynamic> raw) {
    final percent = _findPercent(raw, const ['used_pct', 'used_percent', 'memory_usage', 'usage_percent']);
    final total = _findValue(raw, const ['physmem', 'total_memory', 'memory_total', 'total']);
    final used = _findValue(raw, const ['memory_used', 'used_memory', 'used']);
    final primary = percent == null ? 'Memory diagnostics available' : '${percent.round()}% of memory in use';
    final secondary = [if (used != null) 'Used ${_shortValue(used)}', if (total != null) 'Total ${_shortValue(total)}'].join(' · ');
    return _MetricSummary(percent: percent, primary: primary, secondary: secondary);
  }

  factory _MetricSummary.disk(Map<String, dynamic> raw) {
    final root = _rootDisk(raw);
    final percent = _number(root?['used_pct']) ?? _findPercent(raw, const ['used_pct', 'used_percent']);
    final used = root?['used'];
    final available = root?['available'];
    final primary = percent == null ? 'Disk diagnostics available' : '${percent.round()}% used on /';
    final secondary = [if (used != null) 'Used ${_shortValue(used)}', if (available != null) 'Free ${_shortValue(available)}'].join(' · ');
    return _MetricSummary(percent: percent, primary: primary, secondary: secondary);
  }
}

String? _firstText(Map<String, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    final value = raw[key];
    if (value != null && value.toString().trim().isNotEmpty) return _shortValue(value);
  }
  return null;
}

String _shortValue(dynamic value) {
  if (value == null) return '';
  if (value is List) return value.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).take(2).join(' · ');
  if (value is Map) return value.values.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).take(2).join(' · ');
  final text = value.toString().trim();
  return text.length > 120 ? '${text.substring(0, 117)}…' : text;
}

dynamic _findValue(dynamic node, List<String> keys) {
  if (node is Map) {
    for (final entry in node.entries) {
      final key = entry.key.toString().toLowerCase();
      if (keys.contains(key) && entry.value != null) return entry.value;
    }
    for (final value in node.values) {
      final found = _findValue(value, keys);
      if (found != null) return found;
    }
  } else if (node is List) {
    for (final value in node) {
      final found = _findValue(value, keys);
      if (found != null) return found;
    }
  }
  return null;
}

double? _findPercent(dynamic node, List<String> keys) {
  final value = _findValue(node, keys);
  final n = _number(value);
  if (n == null) return null;
  return n >= 0 && n <= 100 ? n : null;
}

double? _number(dynamic value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString().replaceAll('%', '').trim());
}

Map<String, dynamic>? _rootDisk(Map<String, dynamic> raw) {
  final devices = raw['devices'];
  if (devices is List) {
    for (final item in devices) {
      if (item is Map && item['mountpoint']?.toString() == '/') return Map<String, dynamic>.from(item);
    }
    for (final item in devices) {
      if (item is Map) return Map<String, dynamic>.from(item);
    }
  }
  return null;
}
