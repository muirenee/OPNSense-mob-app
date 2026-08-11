import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../profiles/firewall_profile.dart';
import 'network_models.dart';
import 'network_repository.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({
    super.key,
    required this.profile,
    required this.credentials,
  });

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  late final NetworkRepository _repository;
  NetworkSnapshot? _snapshot;
  Object? _error;
  bool _loading = true;
  Timer? _pollTimer;
  DateTime? _lastCounterTime;

  @override
  void initState() {
    super.initState();
    _repository = NetworkRepository(
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
    );
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = data;
        _loading = false;
        _lastCounterTime = DateTime.now();
      });
      _startPolling();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollCounters());
  }

  Future<void> _pollCounters() async {
    final current = _snapshot;
    final previousAt = _lastCounterTime;
    if (current == null || previousAt == null) return;

    try {
      final counters = await _repository.loadInterfaceCounters();
      final now = DateTime.now();
      final seconds = now.difference(previousAt).inMilliseconds / 1000.0;
      if (seconds <= 0) return;

      final updated = current.interfaces.map((item) {
        final next = counters[item.identifier];
        if (next == null) return item;
        final nextRx = next['rxBytes'];
        final nextTx = next['txBytes'];
        final rxRate = _rate(item.rxBytes, nextRx, seconds);
        final txRate = _rate(item.txBytes, nextTx, seconds);
        return item.copyWith(
          rxBytes: nextRx,
          txBytes: nextTx,
          rxPackets: next['rxPackets'],
          txPackets: next['txPackets'],
          inputErrors: next['inputErrors'],
          outputErrors: next['outputErrors'],
          rxBitsPerSecond: rxRate,
          txBitsPerSecond: txRate,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _snapshot = NetworkSnapshot(
          gateways: current.gateways,
          interfaces: updated,
        );
        _lastCounterTime = now;
      });
    } catch (_) {
      // Live counters are best-effort. Keep the last successful screen state.
    }
  }

  static double _rate(int? before, int? after, double seconds) {
    if (before == null || after == null || after < before || seconds <= 0) {
      return 0;
    }
    return ((after - before) * 8) / seconds;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _snapshot == null) {
      return _NetworkError(error: _error!, onRetry: _load);
    }

    final data = _snapshot!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            'Network',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          const Text('Gateway health and live interface throughput'),
          const SizedBox(height: 16),
          _NetworkCard(
            title: 'Gateways',
            icon: Icons.route_outlined,
            child: data.gateways.isEmpty
                ? const Text('No gateway status records returned.')
                : Column(
                    children: [
                      for (var i = 0; i < data.gateways.length; i++) ...[
                        if (i > 0) const Divider(height: 20),
                        _GatewayRow(gateway: data.gateways[i]),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _NetworkCard(
            title: 'Interfaces',
            icon: Icons.lan_outlined,
            trailing: const _LiveBadge(),
            child: data.interfaces.isEmpty
                ? const Text('No interface records returned.')
                : Column(
                    children: [
                      for (var i = 0; i < data.interfaces.length; i++) ...[
                        if (i > 0) const Divider(height: 22),
                        _InterfaceRow(interface: data.interfaces[i]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _GatewayRow extends StatelessWidget {
  const _GatewayRow({required this.gateway});

  final GatewaySummary gateway;

  @override
  Widget build(BuildContext context) {
    final statusColor = gateway.isOnline
        ? Colors.green
        : Theme.of(context).colorScheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 10, color: statusColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      gateway.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    gateway.status.isEmpty ? 'Unknown' : gateway.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (gateway.interfaceName.isNotEmpty)
                Text('Interface: ${gateway.interfaceName}'),
              if (gateway.address.isNotEmpty) Text('Gateway: ${gateway.address}'),
              if (gateway.monitor.isNotEmpty) Text('Monitor: ${gateway.monitor}'),
              if (gateway.delay.isNotEmpty || gateway.loss.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 12,
                    children: [
                      if (gateway.delay.isNotEmpty) Text('RTT ${gateway.delay}'),
                      if (gateway.loss.isNotEmpty) Text('Loss ${gateway.loss}'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InterfaceRow extends StatelessWidget {
  const _InterfaceRow({required this.interface});

  final NetworkInterfaceSummary interface;

  @override
  Widget build(BuildContext context) {
    final statusColor = interface.isUp
        ? Colors.green
        : Theme.of(context).colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 10, color: statusColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                interface.description,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(interface.status.isEmpty ? 'Unknown' : interface.status),
          ],
        ),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(interface.identifier),
              if (interface.addresses.isNotEmpty)
                Text(interface.addresses.join('  ·  ')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 18,
                runSpacing: 5,
                children: [
                  _Metric(
                    icon: Icons.arrow_downward,
                    label: _formatBitrate(interface.rxBitsPerSecond),
                  ),
                  _Metric(
                    icon: Icons.arrow_upward,
                    label: _formatBitrate(interface.txBitsPerSecond),
                  ),
                  if (interface.inputErrors != null)
                    _Metric(
                      icon: Icons.error_outline,
                      label: 'RX errors ${interface.inputErrors}',
                    ),
                  if (interface.outputErrors != null)
                    _Metric(
                      icon: Icons.error_outline,
                      label: 'TX errors ${interface.outputErrors}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '2s LIVE',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

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
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _NetworkError extends StatelessWidget {
  const _NetworkError({required this.error, required this.onRetry});

  final Object error;
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
            Text('Network data unavailable',
                style: Theme.of(context).textTheme.titleLarge),
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

String _formatBitrate(double bitsPerSecond) {
  if (bitsPerSecond >= 1000000000) {
    return '${(bitsPerSecond / 1000000000).toStringAsFixed(1)} Gbps';
  }
  if (bitsPerSecond >= 1000000) {
    return '${(bitsPerSecond / 1000000).toStringAsFixed(1)} Mbps';
  }
  if (bitsPerSecond >= 1000) {
    return '${(bitsPerSecond / 1000).toStringAsFixed(1)} Kbps';
  }
  return '${bitsPerSecond.toStringAsFixed(0)} bps';
}
