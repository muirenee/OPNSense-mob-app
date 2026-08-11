import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../audit/audit_repository.dart';
import '../profiles/firewall_profile.dart';
import 'vpn_models.dart';
import 'vpn_repository.dart';

class VpnScreen extends StatefulWidget {
  const VpnScreen({
    super.key,
    required this.profile,
    required this.credentials,
  });

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen>
    with SingleTickerProviderStateMixin {
  late final VpnRepository _repository;
  late final AuditRepository _audit;
  late final TabController _tabs;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repository = VpnRepository(
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
    );
    _audit = AuditRepository(profileId: widget.profile.id);
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _serviceAction(VpnKind kind, VpnServiceAction action) async {
    final label = switch (kind) {
      VpnKind.wireGuard => 'WireGuard',
      VpnKind.openVpn => 'OpenVPN',
      VpnKind.ipsec => 'IPsec',
    };
    final verb = switch (action) {
      VpnServiceAction.start => 'Start',
      VpnServiceAction.stop => 'Stop',
      VpnServiceAction.restart => 'Restart',
    };
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$verb $label?'),
            content: Text(
              action == VpnServiceAction.start
                  ? 'Send the $verb command to $label?'
                  : '$verb can interrupt active VPN sessions. Continue?',
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

    setState(() => _busy = true);
    try {
      await _repository.performServiceAction(kind, action);
      try {
        await _audit.record(
          action: 'VPN $verb',
          target: label,
          result: 'success',
        );
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$verb command sent to $label.')),
        );
        setState(() {});
      }
    } catch (error) {
      try {
        await _audit.record(
          action: 'VPN $verb',
          target: label,
          result: 'failed',
          details: error.toString(),
        );
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$verb failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'WireGuard'),
              Tab(text: 'OpenVPN'),
              Tab(text: 'IPsec'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _VpnTab(
                kind: VpnKind.wireGuard,
                repository: _repository,
                busy: _busy,
                onAction: (action) => _serviceAction(VpnKind.wireGuard, action),
              ),
              _VpnTab(
                kind: VpnKind.openVpn,
                repository: _repository,
                busy: _busy,
                onAction: (action) => _serviceAction(VpnKind.openVpn, action),
              ),
              _VpnTab(
                kind: VpnKind.ipsec,
                repository: _repository,
                busy: _busy,
                onAction: (action) => _serviceAction(VpnKind.ipsec, action),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VpnTab extends StatefulWidget {
  const _VpnTab({
    required this.kind,
    required this.repository,
    required this.busy,
    required this.onAction,
  });

  final VpnKind kind;
  final VpnRepository repository;
  final bool busy;
  final ValueChanged<VpnServiceAction> onAction;

  @override
  State<_VpnTab> createState() => _VpnTabState();
}

class _VpnTabState extends State<_VpnTab> {
  late Future<_VpnData> _future;

  String get _label => switch (widget.kind) {
        VpnKind.wireGuard => 'WireGuard',
        VpnKind.openVpn => 'OpenVPN',
        VpnKind.ipsec => 'IPsec',
      };

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _VpnTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy && !widget.busy) {
      _future = _load();
    }
  }

  Future<_VpnData> _load() async {
    VpnServiceStatus? status;
    Object? statusError;
    try {
      if (widget.kind == VpnKind.wireGuard) {
        status = await widget.repository.loadWireGuardStatus();
      } else if (widget.kind == VpnKind.ipsec) {
        status = await widget.repository.loadIpsecStatus();
      }
    } catch (error) {
      statusError = error;
    }

    try {
      final sessions = switch (widget.kind) {
        VpnKind.wireGuard => await widget.repository.loadWireGuardSessions(),
        VpnKind.openVpn => await widget.repository.loadOpenVpnSessions(),
        VpnKind.ipsec => await widget.repository.loadIpsecSessions(),
      };
      return _VpnData(status: status, sessions: sessions, statusError: statusError);
    } catch (error) {
      return _VpnData(
        status: status,
        sessions: const [],
        statusError: statusError,
        sessionsError: error,
      );
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_VpnData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data ?? const _VpnData(sessions: []);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _label,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  PopupMenuButton<VpnServiceAction>(
                    enabled: !widget.busy,
                    onSelected: widget.onAction,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: VpnServiceAction.start,
                        child: Text('Start'),
                      ),
                      PopupMenuItem(
                        value: VpnServiceAction.restart,
                        child: Text('Restart'),
                      ),
                      PopupMenuItem(
                        value: VpnServiceAction.stop,
                        child: Text('Stop'),
                      ),
                    ],
                  ),
                ],
              ),
              if (widget.busy) const LinearProgressIndicator(),
              const SizedBox(height: 10),
              if (data.status != null)
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.circle,
                      size: 12,
                      color: data.status!.isRunning
                          ? Colors.green
                          : Theme.of(context).colorScheme.outline,
                    ),
                    title: const Text('Service status'),
                    subtitle: Text(data.status!.status),
                  ),
                )
              else if (data.statusError != null)
                _ErrorCard(title: 'Service status unavailable', error: data.statusError),
              const SizedBox(height: 8),
              Text(
                'Sessions / peers',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              if (data.sessionsError != null)
                _ErrorCard(title: 'Session data unavailable', error: data.sessionsError)
              else if (data.sessions.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No active sessions or peers were returned.'),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < data.sessions.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _SessionTile(session: data.sessions[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Start, stop and restart require confirmation and are recorded in the local audit trail.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final VpnSession session;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (session.remote.isNotEmpty) 'Remote: ${session.remote}',
      if (session.virtualAddress.isNotEmpty) 'Tunnel: ${session.virtualAddress}',
      if (session.connectedSince.isNotEmpty) 'Since/handshake: ${session.connectedSince}',
      if (session.bytesIn.isNotEmpty || session.bytesOut.isNotEmpty)
        'RX ${session.bytesIn.isEmpty ? '—' : session.bytesIn} · TX ${session.bytesOut.isEmpty ? '—' : session.bytesOut}',
      if (session.details.isNotEmpty) session.details,
    ];
    return ListTile(
      leading: Icon(
        Icons.vpn_lock_outlined,
        color: session.isConnected ? Colors.green : null,
      ),
      title: Text(session.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        [session.status, ...lines].where((item) => item.isNotEmpty).join('\n'),
      ),
      isThreeLine: lines.isNotEmpty,
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.title, required this.error});

  final String title;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.error),
        title: Text(title),
        subtitle: Text(error.toString()),
      ),
    );
  }
}

class _VpnData {
  const _VpnData({
    this.status,
    required this.sessions,
    this.statusError,
    this.sessionsError,
  });

  final VpnServiceStatus? status;
  final List<VpnSession> sessions;
  final Object? statusError;
  final Object? sessionsError;
}
