import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../audit/audit_repository.dart';
import '../profiles/firewall_profile.dart';
import 'captive_portal_models.dart';
import 'captive_portal_repository.dart';

class CaptivePortalScreen extends StatefulWidget {
  const CaptivePortalScreen({
    super.key,
    required this.profile,
    required this.credentials,
  });

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<CaptivePortalScreen> createState() => _CaptivePortalScreenState();
}

class _CaptivePortalScreenState extends State<CaptivePortalScreen> {
  late final CaptivePortalRepository _repository;
  late final AuditRepository _audit;
  late Future<List<CaptivePortalZone>> _zones;
  late Future<List<CaptivePortalSession>> _sessions;
  late Future<List<String>> _providers;
  String _zoneQuery = '';
  String _sessionQuery = '';

  @override
  void initState() {
    super.initState();
    _repository = CaptivePortalRepository(
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
    );
    _audit = AuditRepository(profileId: widget.profile.id);
    _reload();
  }

  void _reload() {
    _zones = _repository.loadZones();
    _sessions = _repository.loadSessions();
    _providers = _repository.loadVoucherProviders();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait<dynamic>([_zones, _sessions, _providers]);
  }

  Future<void> _editZone([CaptivePortalZone? zone]) async {
    Map<String, dynamic> initial = <String, dynamic>{};
    if (zone != null && zone.uuid.isNotEmpty) {
      try {
        initial = await _repository.getZone(zone.uuid);
      } catch (_) {}
    }
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ZoneEditor(
          repository: _repository,
          audit: _audit,
          zone: zone,
          initial: initial,
        ),
      ),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _toggleZone(CaptivePortalZone zone) async {
    final enable = !zone.enabled;
    final ok = await _confirm(
      '${enable ? 'Enable' : 'Disable'} captive portal zone?',
      '${enable ? 'Enable' : 'Disable'} ${zone.description}? Client authentication may be affected immediately.',
      enable ? 'Enable' : 'Disable',
    );
    if (!ok) return;
    try {
      await _repository.toggleZone(zone, enable);
      await _record('${enable ? 'Enable' : 'Disable'} captive portal zone', zone.description, 'success');
      await _refresh();
    } catch (error) {
      await _record('Toggle captive portal zone', zone.description, 'failed', error.toString());
      _message('Zone change failed: $error');
    }
  }

  Future<void> _deleteZone(CaptivePortalZone zone) async {
    final ok = await _confirm(
      'Delete captive portal zone?',
      'Delete ${zone.description}? Active sessions and authentication on this zone will be affected.',
      'Delete',
    );
    if (!ok) return;
    try {
      await _repository.deleteZone(zone.uuid);
      await _record('Delete captive portal zone', zone.description, 'success');
      await _refresh();
    } catch (error) {
      await _record('Delete captive portal zone', zone.description, 'failed', error.toString());
      _message('Zone delete failed: $error');
    }
  }

  Future<void> _disconnect(CaptivePortalSession session) async {
    final label = session.username.isEmpty ? session.ip : session.username;
    final ok = await _confirm(
      'Disconnect session?',
      'Disconnect $label from the captive portal?',
      'Disconnect',
    );
    if (!ok) return;
    try {
      await _repository.disconnectSession(session.sessionId);
      await _record('Disconnect captive portal session', label, 'success');
      await _refresh();
    } catch (error) {
      await _record('Disconnect captive portal session', label, 'failed', error.toString());
      _message('Session disconnect failed: $error');
    }
  }

  Future<void> _authorizeClient() async {
    final zones = await _repository.loadSessionZones();
    if (!mounted) return;
    final zoneId = ValueNotifier<String>(zones.keys.isEmpty ? '0' : zones.keys.first);
    final user = TextEditingController();
    final ip = TextEditingController();
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Authorize client'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: zoneId,
                  builder: (_, value, __) => DropdownButtonFormField<String>(
                    initialValue: value,
                    decoration: const InputDecoration(labelText: 'Zone'),
                    items: zones.entries
                        .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) zoneId.value = value;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: user, decoration: const InputDecoration(labelText: 'Username')),
                const SizedBox(height: 12),
                TextField(controller: ip, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Client IP')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Authorize')),
            ],
          ),
        ) ??
        false;
    if (!ok || user.text.trim().isEmpty || ip.text.trim().isEmpty) return;
    try {
      await _repository.authorizeClient(zoneId: zoneId.value, username: user.text.trim(), ip: ip.text.trim());
      await _record('Authorize captive portal client', user.text.trim(), 'success', ip.text.trim());
      await _refresh();
    } catch (error) {
      _message('Client authorization failed: $error');
    } finally {
      zoneId.dispose();
      user.dispose();
      ip.dispose();
    }
  }

  Future<bool> _confirm(String title, String text, String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(text),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _record(String action, String target, String result, [String details = '']) async {
    try {
      await _audit.record(action: action, target: target, result: result, details: details);
    } catch (_) {}
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Captive Portal'),
          actions: [
            IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Zones', icon: Icon(Icons.wifi_tethering_outlined)),
              Tab(text: 'Sessions', icon: Icon(Icons.devices_outlined)),
              Tab(text: 'Vouchers', icon: Icon(Icons.confirmation_number_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _zonesTab(),
            _sessionsTab(),
            _VoucherTab(repository: _repository, audit: _audit, providers: _providers),
          ],
        ),
      ),
    );
  }

  Widget _zonesTab() {
    return FutureBuilder<List<CaptivePortalZone>>(
      future: _zones,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _error('Captive portal zones unavailable', snapshot.error);
        final zones = snapshot.data ?? const <CaptivePortalZone>[];
        final query = _zoneQuery.trim().toLowerCase();
        final filtered = zones.where((zone) =>
            query.isEmpty ||
            zone.description.toLowerCase().contains(query) ||
            zone.interfaces.toLowerCase().contains(query) ||
            zone.zoneId.contains(query)).toList();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _header('Portal zones', '${filtered.length} of ${zones.length} shown', () => _editZone()),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => _zoneQuery = value),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search zones or interfaces'),
              ),
              const SizedBox(height: 14),
              for (final zone in filtered) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(zone.enabled ? Icons.wifi_tethering : Icons.wifi_tethering_off, color: zone.enabled ? Colors.green : Theme.of(context).colorScheme.outline),
                            const SizedBox(width: 10),
                            Expanded(child: Text(zone.description.isEmpty ? 'Zone ${zone.zoneId}' : zone.description, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                            Switch.adaptive(value: zone.enabled, onChanged: (_) => _toggleZone(zone)),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _editZone(zone);
                                if (value == 'delete') _deleteZone(zone);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text('Zone ${zone.zoneId}')),
                            Chip(label: Text(zone.enabled ? 'Enabled' : 'Disabled')),
                            if (zone.interfaces.isNotEmpty) Chip(label: Text(zone.interfaces)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Idle ${zone.idleTimeout} min · Hard ${zone.hardTimeout} min'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (filtered.isEmpty) _empty('No captive portal zones match the search.'),
            ],
          ),
        );
      },
    );
  }

  Widget _sessionsTab() {
    return FutureBuilder<List<CaptivePortalSession>>(
      future: _sessions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _error('Captive portal sessions unavailable', snapshot.error);
        final sessions = snapshot.data ?? const <CaptivePortalSession>[];
        final query = _sessionQuery.trim().toLowerCase();
        final filtered = sessions.where((item) =>
            query.isEmpty ||
            item.username.toLowerCase().contains(query) ||
            item.ip.toLowerCase().contains(query) ||
            item.mac.toLowerCase().contains(query) ||
            item.zoneId.toLowerCase().contains(query)).toList();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _header('Active sessions', '${filtered.length} of ${sessions.length} shown', _authorizeClient, addLabel: 'Authorize'),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => _sessionQuery = value),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search username, IP, MAC or zone'),
              ),
              const SizedBox(height: 14),
              for (final session in filtered) ...[
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.devices_outlined)),
                    title: Text(session.username.isEmpty ? session.ip : session.username, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text([
                      if (session.ip.isNotEmpty) session.ip,
                      if (session.mac.isNotEmpty) session.mac,
                      if (session.zoneId.isNotEmpty) 'Zone ${session.zoneId}',
                      if (session.timeLeft.isNotEmpty) 'Time left ${session.timeLeft}',
                    ].join(' · ')),
                    trailing: IconButton(
                      tooltip: 'Disconnect',
                      onPressed: session.sessionId.isEmpty ? null : () => _disconnect(session),
                      icon: const Icon(Icons.link_off),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (filtered.isEmpty) _empty('No captive portal sessions match the search.'),
            ],
          ),
        );
      },
    );
  }

  Widget _header(String title, String subtitle, VoidCallback onAdd, {String addLabel = 'Add'}) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(addLabel)),
        ],
      );

  Widget _empty(String text) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(text)));

  Widget _error(String title, Object? error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_tethering_error_outlined, size: 48),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
}

class _ZoneEditor extends StatefulWidget {
  const _ZoneEditor({
    required this.repository,
    required this.audit,
    required this.initial,
    this.zone,
  });

  final CaptivePortalRepository repository;
  final AuditRepository audit;
  final Map<String, dynamic> initial;
  final CaptivePortalZone? zone;

  @override
  State<_ZoneEditor> createState() => _ZoneEditorState();
}

class _ZoneEditorState extends State<_ZoneEditor> {
  late final TextEditingController _description;
  late final TextEditingController _interfaces;
  late final TextEditingController _authServers;
  late final TextEditingController _idle;
  late final TextEditingController _hard;
  late final TextEditingController _serverName;
  late final TextEditingController _allowedAddresses;
  late final TextEditingController _allowedMacs;
  bool _enabled = true;
  bool _roaming = true;
  bool _concurrent = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    String text(String key, String fallback) => widget.initial[key]?.toString() ?? fallback;
    _description = TextEditingController(text: text('description', widget.zone?.description ?? ''));
    _interfaces = TextEditingController(text: text('interfaces', widget.zone?.interfaces ?? 'lan'));
    _authServers = TextEditingController(text: text('authservers', widget.zone?.authServers ?? ''));
    _idle = TextEditingController(text: text('idletimeout', widget.zone?.idleTimeout ?? '0'));
    _hard = TextEditingController(text: text('hardtimeout', widget.zone?.hardTimeout ?? '0'));
    _serverName = TextEditingController(text: text('servername', widget.zone?.serverName ?? ''));
    _allowedAddresses = TextEditingController(text: text('allowedAddresses', ''));
    _allowedMacs = TextEditingController(text: text('allowedMACAddresses', ''));
    _enabled = _bool(widget.initial['enabled'], widget.zone?.enabled ?? true);
    _roaming = _bool(widget.initial['roaming'], widget.zone?.roaming ?? true);
    _concurrent = _bool(widget.initial['concurrentlogins'], widget.zone?.concurrentLogins ?? true);
  }

  bool _bool(dynamic value, bool fallback) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    return const {'1', 'true', 'yes', 'on'}.contains(value.toString().toLowerCase());
  }

  @override
  void dispose() {
    for (final controller in [_description, _interfaces, _authServers, _idle, _hard, _serverName, _allowedAddresses, _allowedMacs]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_description.text.trim().isEmpty || _interfaces.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Description and interface are required.')));
      return;
    }
    setState(() => _busy = true);
    final data = <String, dynamic>{
      'description': _description.text.trim(),
      'interfaces': _interfaces.text.trim(),
      'authservers': _authServers.text.trim(),
      'idletimeout': _idle.text.trim().isEmpty ? '0' : _idle.text.trim(),
      'hardtimeout': _hard.text.trim().isEmpty ? '0' : _hard.text.trim(),
      'servername': _serverName.text.trim(),
      'allowedAddresses': _allowedAddresses.text.trim(),
      'allowedMACAddresses': _allowedMacs.text.trim(),
      'enabled': _enabled ? '1' : '0',
      'roaming': _roaming ? '1' : '0',
      'concurrentlogins': _concurrent ? '1' : '0',
      'disableRules': widget.initial['disableRules']?.toString() ?? '0',
      'alwaysSendAccountingReqs': widget.initial['alwaysSendAccountingReqs']?.toString() ?? '0',
      'extendedPreAuthData': widget.initial['extendedPreAuthData']?.toString() ?? '0',
    };
    try {
      await widget.repository.saveZone(uuid: widget.zone?.uuid, values: data);
      try {
        await widget.audit.record(
          action: widget.zone == null ? 'Add captive portal zone' : 'Edit captive portal zone',
          target: _description.text.trim(),
          result: 'success',
        );
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save zone: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.zone != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit portal zone' : 'Add portal zone')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 12),
          TextField(controller: _interfaces, decoration: const InputDecoration(labelText: 'Interfaces', hintText: 'lan or comma-separated interface identifiers')),
          const SizedBox(height: 12),
          TextField(controller: _authServers, decoration: const InputDecoration(labelText: 'Authentication servers', hintText: 'Optional server identifiers')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _idle, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Idle timeout (min)'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _hard, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hard timeout (min)'))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _serverName, decoration: const InputDecoration(labelText: 'Server name')),
          const SizedBox(height: 12),
          TextField(controller: _allowedAddresses, maxLines: 2, decoration: const InputDecoration(labelText: 'Allowed addresses', hintText: 'Optional list')),
          const SizedBox(height: 12),
          TextField(controller: _allowedMacs, maxLines: 2, decoration: const InputDecoration(labelText: 'Allowed MAC addresses', hintText: 'Optional list')),
          SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Enabled'), value: _enabled, onChanged: (value) => setState(() => _enabled = value)),
          SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Roaming'), value: _roaming, onChanged: (value) => setState(() => _roaming = value)),
          SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Concurrent logins'), value: _concurrent, onChanged: (value) => setState(() => _concurrent = value)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            label: Text(editing ? 'Save changes' : 'Add zone'),
          ),
        ],
      ),
    );
  }
}

class _VoucherTab extends StatefulWidget {
  const _VoucherTab({required this.repository, required this.audit, required this.providers});
  final CaptivePortalRepository repository;
  final AuditRepository audit;
  final Future<List<String>> providers;

  @override
  State<_VoucherTab> createState() => _VoucherTabState();
}

class _VoucherTabState extends State<_VoucherTab> {
  String? _provider;
  String? _group;
  List<String> _groups = const [];
  List<CaptivePortalVoucher> _vouchers = const [];
  bool _busy = false;

  Future<void> _selectProvider(String? value) async {
    if (value == null) return;
    setState(() {
      _provider = value;
      _group = null;
      _groups = const [];
      _vouchers = const [];
      _busy = true;
    });
    try {
      final groups = await widget.repository.loadVoucherGroups(value);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _group = groups.isEmpty ? null : groups.first;
      });
      if (_group != null) await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    if (_provider == null || _group == null) return;
    setState(() => _busy = true);
    try {
      final values = await widget.repository.loadVouchers(_provider!, _group!);
      if (mounted) setState(() => _vouchers = values);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to load vouchers: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate() async {
    if (_provider == null || _group == null) return;
    final count = TextEditingController(text: '10');
    final validity = TextEditingController(text: '60');
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Generate vouchers'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Count')),
                const SizedBox(height: 12),
                TextField(controller: validity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Validity (minutes)')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generate')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    final number = int.tryParse(count.text) ?? 0;
    final minutes = int.tryParse(validity.text) ?? 0;
    count.dispose();
    validity.dispose();
    if (number < 1 || number > 10000 || minutes < 1) return;
    try {
      final generated = await widget.repository.generateVouchers(
        provider: _provider!,
        group: _group!,
        count: number,
        validityMinutes: minutes,
      );
      try {
        await widget.audit.record(action: 'Generate captive portal vouchers', target: _group!, result: 'success', details: '$number vouchers');
      } catch (_) {}
      if (!mounted) return;
      if (generated.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Generated vouchers'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: SelectableText(generated.map((v) => v.password.isEmpty ? v.username : '${v.username}  ${v.password}').join('\n')),
              ),
            ),
            actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
          ),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voucher generation failed: $error')));
    }
  }

  Future<void> _expire(CaptivePortalVoucher voucher) async {
    if (_provider == null) return;
    try {
      await widget.repository.expireVoucher(_provider!, voucher.username);
      try {
        await widget.audit.record(action: 'Expire captive portal voucher', target: voucher.username, result: 'success');
      } catch (_) {}
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to expire voucher: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: widget.providers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Voucher providers unavailable\n${snapshot.error}', textAlign: TextAlign.center));
        final providers = snapshot.data ?? const <String>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            Row(children: [
              Expanded(child: Text('Vouchers', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              FilledButton.icon(onPressed: _provider == null || _group == null ? null : _generate, icon: const Icon(Icons.add), label: const Text('Generate')),
            ]),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _provider,
              decoration: const InputDecoration(labelText: 'Provider'),
              items: providers.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: _selectProvider,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _group,
              decoration: const InputDecoration(labelText: 'Voucher group'),
              items: _groups.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) async {
                setState(() => _group = value);
                await _load();
              },
            ),
            const SizedBox(height: 14),
            if (_busy) const LinearProgressIndicator(),
            if (!_busy && _provider == null) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Select a voucher provider to manage voucher groups.'))),
            for (final voucher in _vouchers) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: SelectableText(voucher.username, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text([
                    if (voucher.validity.isNotEmpty) 'Validity ${voucher.validity}',
                    if (voucher.expiry.isNotEmpty) 'Expiry ${voucher.expiry}',
                    if (voucher.used.isNotEmpty) voucher.used,
                  ].join(' · ')),
                  trailing: IconButton(tooltip: 'Expire', onPressed: () => _expire(voucher), icon: const Icon(Icons.timer_off_outlined)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}
