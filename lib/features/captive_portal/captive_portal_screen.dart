import 'package:flutter/material.dart';

import '../../core/api/api_choice.dart';
import '../../core/api/opnsense_api_client.dart';
import '../../core/widgets/api_select_fields.dart';
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
      OpnSenseApiClient(
        profile: widget.profile,
        credentials: widget.credentials,
      ),
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
    try {
      initial = await _repository.getZone(zone?.uuid);
    } catch (error) {
      if (zone != null) _message('Advanced zone options could not be loaded: $error');
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
      await _record(
        '${enable ? 'Enable' : 'Disable'} captive portal zone',
        zone.description,
        'success',
      );
      await _refresh();
    } catch (error) {
      await _record(
        'Toggle captive portal zone',
        zone.description,
        'failed',
        error.toString(),
      );
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
      await _record(
        'Delete captive portal zone',
        zone.description,
        'failed',
        error.toString(),
      );
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
      await _record(
        'Disconnect captive portal session',
        label,
        'failed',
        error.toString(),
      );
      _message('Session disconnect failed: $error');
    }
  }

  Future<void> _authorizeClient() async {
    final zones = await _repository.loadSessionZones();
    if (!mounted) return;
    if (zones.isEmpty) {
      _message('No captive portal zones are available for authorization.');
      return;
    }
    final zoneId = ValueNotifier<String>(zones.keys.first);
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
                  builder: (_, value, child) => DropdownButtonFormField<String>(
                    initialValue: value,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Zone'),
                    items: zones.entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (selected) {
                      if (selected != null) zoneId.value = selected;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: user,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ip,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Client IP'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Authorize'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || user.text.trim().isEmpty || ip.text.trim().isEmpty) {
      zoneId.dispose();
      user.dispose();
      ip.dispose();
      return;
    }
    try {
      await _repository.authorizeClient(
        zoneId: zoneId.value,
        username: user.text.trim(),
        ip: ip.text.trim(),
      );
      await _record(
        'Authorize captive portal client',
        user.text.trim(),
        'success',
        ip.text.trim(),
      );
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
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _record(
    String action,
    String target,
    String result, [
    String details = '',
  ]) async {
    try {
      await _audit.record(
        action: action,
        target: target,
        result: result,
        details: details,
      );
    } catch (_) {}
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Captive Portal'),
          actions: [
            IconButton(
              onPressed: _refresh,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Zones', icon: Icon(Icons.wifi_tethering_outlined)),
              Tab(text: 'Sessions', icon: Icon(Icons.devices_outlined)),
              Tab(
                text: 'Vouchers',
                icon: Icon(Icons.confirmation_number_outlined),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _zonesTab(),
            _sessionsTab(),
            _VoucherTab(
              repository: _repository,
              audit: _audit,
              providers: _providers,
            ),
          ],
        ),
      ),
    );
  }

  Widget _zonesTab() {
    return FutureBuilder<List<CaptivePortalZone>>(
      future: _zones,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _error('Captive portal zones unavailable', snapshot.error);
        }
        final zones = snapshot.data ?? const <CaptivePortalZone>[];
        final query = _zoneQuery.trim().toLowerCase();
        final filtered = zones.where((zone) {
          return query.isEmpty ||
              zone.description.toLowerCase().contains(query) ||
              zone.interfaces.toLowerCase().contains(query) ||
              zone.authServers.toLowerCase().contains(query) ||
              zone.zoneId.toLowerCase().contains(query);
        }).toList();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _header(
                'Portal zones',
                '${filtered.length} of ${zones.length} shown',
                () => _editZone(),
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => _zoneQuery = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search zones, interfaces or auth servers',
                ),
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
                            Icon(
                              zone.enabled
                                  ? Icons.wifi_tethering
                                  : Icons.wifi_tethering_off,
                              color: zone.enabled
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                zone.description.isEmpty
                                    ? 'Zone ${zone.zoneId}'
                                    : zone.description,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: zone.enabled,
                              onChanged: (_) => _toggleZone(zone),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _editZone(zone);
                                if (value == 'delete') _deleteZone(zone);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
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
                            Chip(
                              label: Text(zone.enabled ? 'Enabled' : 'Disabled'),
                            ),
                            if (zone.interfaces.isNotEmpty)
                              Chip(label: Text(zone.interfaces)),
                          ],
                        ),
                        if (zone.authServers.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Authentication: ${zone.authServers}'),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'Idle ${zone.idleTimeout} min · Hard ${zone.hardTimeout} min',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (filtered.isEmpty)
                _empty('No captive portal zones match the search.'),
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
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _error('Captive portal sessions unavailable', snapshot.error);
        }
        final sessions = snapshot.data ?? const <CaptivePortalSession>[];
        final query = _sessionQuery.trim().toLowerCase();
        final filtered = sessions.where((item) {
          return query.isEmpty ||
              item.username.toLowerCase().contains(query) ||
              item.ip.toLowerCase().contains(query) ||
              item.mac.toLowerCase().contains(query) ||
              item.zoneId.toLowerCase().contains(query);
        }).toList();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _header(
                'Active sessions',
                '${filtered.length} of ${sessions.length} shown',
                _authorizeClient,
                addLabel: 'Authorize',
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => _sessionQuery = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search username, IP, MAC or zone',
                ),
              ),
              const SizedBox(height: 14),
              for (final session in filtered) ...[
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.devices_outlined),
                    ),
                    title: Text(
                      session.username.isEmpty ? session.ip : session.username,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      [
                        if (session.ip.isNotEmpty) session.ip,
                        if (session.mac.isNotEmpty) session.mac,
                        if (session.zoneId.isNotEmpty) 'Zone ${session.zoneId}',
                        if (session.timeLeft.isNotEmpty)
                          'Time left ${session.timeLeft}',
                      ].join(' · '),
                    ),
                    trailing: IconButton(
                      tooltip: 'Disconnect',
                      onPressed: session.sessionId.isEmpty
                          ? null
                          : () => _disconnect(session),
                      icon: const Icon(Icons.link_off),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (filtered.isEmpty)
                _empty('No captive portal sessions match the search.'),
            ],
          ),
        );
      },
    );
  }

  Widget _header(
    String title,
    String subtitle,
    VoidCallback onAdd, {
    String addLabel = 'Add',
  }) =>
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(addLabel),
          ),
        ],
      );

  Widget _empty(String text) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(text),
        ),
      );

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
              FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
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
  late final TextEditingController _idle;
  late final TextEditingController _hard;
  late final TextEditingController _serverName;
  late final TextEditingController _allowedAddresses;
  late final TextEditingController _allowedMacs;
  late final List<ApiChoice> _interfaceChoices;
  late final List<ApiChoice> _authServerChoices;
  late final List<ApiChoice> _authGroupChoices;
  late final List<ApiChoice> _certificateChoices;
  late final List<ApiChoice> _templateChoices;
  late Set<String> _interfaces;
  late Set<String> _authServers;
  String? _authGroup;
  String? _certificate;
  String? _template;
  bool _enabled = true;
  bool _roaming = true;
  bool _concurrent = true;
  bool _disableRules = false;
  bool _alwaysAccounting = false;
  bool _extendedPreAuth = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(
      text: _scalar(
        widget.initial['description'],
        widget.zone?.description ?? '',
      ),
    );
    _idle = TextEditingController(
      text: _scalar(
        widget.initial['idletimeout'],
        widget.zone?.idleTimeout ?? '0',
      ),
    );
    _hard = TextEditingController(
      text: _scalar(
        widget.initial['hardtimeout'],
        widget.zone?.hardTimeout ?? '0',
      ),
    );
    _serverName = TextEditingController(
      text: _scalar(
        widget.initial['servername'],
        widget.zone?.serverName ?? '',
      ),
    );
    _allowedAddresses = TextEditingController(
      text: _listText(widget.initial['allowedAddresses']),
    );
    _allowedMacs = TextEditingController(
      text: _listText(widget.initial['allowedMACAddresses']),
    );

    _interfaceChoices = CaptivePortalRepository.choices(
      widget.initial,
      'interfaces',
    );
    _interfaces = CaptivePortalRepository.selectedChoices(
      widget.initial,
      'interfaces',
    );
    if (_interfaces.isEmpty && widget.zone?.interfaces.isNotEmpty == true) {
      _interfaces = _splitValues(widget.zone!.interfaces);
    }

    _authServerChoices = CaptivePortalRepository.choices(
      widget.initial,
      'authservers',
    );
    _authServers = CaptivePortalRepository.selectedChoices(
      widget.initial,
      'authservers',
    );

    _authGroupChoices = CaptivePortalRepository.choices(
      widget.initial,
      'authEnforceGroup',
    );
    _authGroup = CaptivePortalRepository.selectedOne(
      widget.initial,
      'authEnforceGroup',
    );
    _certificateChoices = CaptivePortalRepository.choices(
      widget.initial,
      'certificate',
    );
    _certificate = CaptivePortalRepository.selectedOne(
      widget.initial,
      'certificate',
    );
    _templateChoices = CaptivePortalRepository.choices(
      widget.initial,
      'template',
    );
    _template = CaptivePortalRepository.selectedOne(widget.initial, 'template');

    _enabled = _bool(widget.initial['enabled'], widget.zone?.enabled ?? true);
    _roaming = _bool(widget.initial['roaming'], widget.zone?.roaming ?? true);
    _concurrent = _bool(
      widget.initial['concurrentlogins'],
      widget.zone?.concurrentLogins ?? true,
    );
    _disableRules = _bool(widget.initial['disableRules'], false);
    _alwaysAccounting = _bool(widget.initial['alwaysSendAccountingReqs'], false);
    _extendedPreAuth = _bool(widget.initial['extendedPreAuthData'], false);
  }

  @override
  void dispose() {
    _description.dispose();
    _idle.dispose();
    _hard.dispose();
    _serverName.dispose();
    _allowedAddresses.dispose();
    _allowedMacs.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_description.text.trim().isEmpty) {
      _show('Description is required.');
      return;
    }
    if (_interfaces.isEmpty) {
      _show('Select at least one interface.');
      return;
    }

    setState(() => _busy = true);
    final data = <String, dynamic>{
      'description': _description.text.trim(),
      'interfaces': CaptivePortalRepository.encodeChoices(_interfaces),
      'authservers': CaptivePortalRepository.encodeChoices(_authServers),
      'idletimeout': _idle.text.trim().isEmpty ? '0' : _idle.text.trim(),
      'hardtimeout': _hard.text.trim().isEmpty ? '0' : _hard.text.trim(),
      'servername': _serverName.text.trim(),
      'allowedAddresses': _normalizeLines(_allowedAddresses.text),
      'allowedMACAddresses': _normalizeLines(_allowedMacs.text),
      'enabled': _enabled ? '1' : '0',
      'roaming': _roaming ? '1' : '0',
      'concurrentlogins': _concurrent ? '1' : '0',
      'disableRules': _disableRules ? '1' : '0',
      'alwaysSendAccountingReqs': _alwaysAccounting ? '1' : '0',
      'extendedPreAuthData': _extendedPreAuth ? '1' : '0',
    };
    if (widget.initial.containsKey('authEnforceGroup')) {
      data['authEnforceGroup'] = _authGroup ?? '';
    }
    if (widget.initial.containsKey('certificate')) {
      data['certificate'] = _certificate ?? '';
    }
    if (widget.initial.containsKey('template')) {
      data['template'] = _template ?? '';
    }

    try {
      await widget.repository.saveZone(uuid: widget.zone?.uuid, values: data);
      try {
        await widget.audit.record(
          action: widget.zone == null
              ? 'Add captive portal zone'
              : 'Edit captive portal zone',
          target: _description.text.trim(),
          result: 'success',
          details:
              '${_interfaces.length} interfaces · ${_authServers.length} auth servers',
        );
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _show('Unable to save zone: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
          _Section(
            title: 'Zone',
            icon: Icons.wifi_tethering_outlined,
            children: [
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              ApiMultiSelectField(
                label: 'Interfaces',
                choices: _interfaceChoices,
                selected: _interfaces,
                prefixIcon: Icons.settings_ethernet,
                helperText: 'Interfaces where the captive portal is active.',
                searchHint: 'Search interfaces',
                onChanged: (values) => setState(() => _interfaces = values),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _serverName,
                decoration: const InputDecoration(labelText: 'Server name'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Authentication',
            icon: Icons.verified_user_outlined,
            children: [
              ApiMultiSelectField(
                label: 'Authentication servers',
                choices: _authServerChoices,
                selected: _authServers,
                prefixIcon: Icons.dns_outlined,
                helperText: 'Select one or more authentication providers.',
                searchHint: 'Search authentication servers',
                onChanged: (values) => setState(() => _authServers = values),
              ),
              if (_authGroupChoices.isNotEmpty) ...[
                const SizedBox(height: 12),
                ApiSingleSelectField(
                  label: 'Enforce group',
                  choices: _authGroupChoices,
                  value: _authGroup,
                  prefixIcon: Icons.group_outlined,
                  helperText: 'Optionally require membership in one group.',
                  onChanged: (value) => setState(() => _authGroup = value),
                ),
              ],
              if (_certificateChoices.isNotEmpty) ...[
                const SizedBox(height: 12),
                ApiSingleSelectField(
                  label: 'HTTPS certificate',
                  choices: _certificateChoices,
                  value: _certificate,
                  prefixIcon: Icons.verified_outlined,
                  onChanged: (value) => setState(() => _certificate = value),
                ),
              ],
              if (_templateChoices.isNotEmpty) ...[
                const SizedBox(height: 12),
                ApiSingleSelectField(
                  label: 'Portal template',
                  choices: _templateChoices,
                  value: _template,
                  prefixIcon: Icons.web_asset_outlined,
                  onChanged: (value) => setState(() => _template = value),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Session policy',
            icon: Icons.timer_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _idle,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Idle timeout (min)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _hard,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Hard timeout (min)',
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Roaming'),
                value: _roaming,
                onChanged: (value) => setState(() => _roaming = value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Concurrent logins'),
                value: _concurrent,
                onChanged: (value) => setState(() => _concurrent = value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Always send accounting requests'),
                value: _alwaysAccounting,
                onChanged: (value) => setState(() => _alwaysAccounting = value),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Allowed clients & advanced',
            icon: Icons.tune,
            children: [
              TextField(
                controller: _allowedAddresses,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Allowed addresses',
                  hintText: 'One IP/network per line or comma-separated',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _allowedMacs,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Allowed MAC addresses',
                  hintText: 'One MAC per line or comma-separated',
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disable automatic firewall rules'),
                value: _disableRules,
                onChanged: (value) => setState(() => _disableRules = value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Extended pre-authentication data'),
                value: _extendedPreAuth,
                onChanged: (value) => setState(() => _extendedPreAuth = value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(editing ? 'Save changes' : 'Add zone'),
          ),
        ],
      ),
    );
  }
}

class _VoucherTab extends StatefulWidget {
  const _VoucherTab({
    required this.repository,
    required this.audit,
    required this.providers,
  });

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
    } catch (error) {
      _show('Unable to load voucher groups: $error');
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
      _show('Unable to load vouchers: $error');
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
                TextField(
                  controller: count,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Count'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: validity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Validity (minutes)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Generate'),
              ),
            ],
          ),
        ) ??
        false;
    final number = int.tryParse(count.text) ?? 0;
    final minutes = int.tryParse(validity.text) ?? 0;
    count.dispose();
    validity.dispose();
    if (!ok || number < 1 || number > 10000 || minutes < 1) return;

    try {
      final generated = await widget.repository.generateVouchers(
        provider: _provider!,
        group: _group!,
        count: number,
        validityMinutes: minutes,
      );
      try {
        await widget.audit.record(
          action: 'Generate captive portal vouchers',
          target: _group!,
          result: 'success',
          details: '$number vouchers',
        );
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
                child: SelectableText(
                  generated
                      .map(
                        (voucher) => voucher.password.isEmpty
                            ? voucher.username
                            : '${voucher.username}  ${voucher.password}',
                      )
                      .join('\n'),
                ),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
      await _load();
    } catch (error) {
      _show('Voucher generation failed: $error');
    }
  }

  Future<void> _expire(CaptivePortalVoucher voucher) async {
    if (_provider == null) return;
    try {
      await widget.repository.expireVoucher(_provider!, voucher.username);
      try {
        await widget.audit.record(
          action: 'Expire captive portal voucher',
          target: voucher.username,
          result: 'success',
        );
      } catch (_) {}
      await _load();
    } catch (error) {
      _show('Unable to expire voucher: $error');
    }
  }

  void _show(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: widget.providers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Voucher providers unavailable\n${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }
        final providers = snapshot.data ?? const <String>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Vouchers',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _provider == null || _group == null ? null : _generate,
                  icon: const Icon(Icons.add),
                  label: const Text('Generate'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _provider,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Provider'),
              items: providers
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: _selectProvider,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _group,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Voucher group'),
              items: _groups
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                setState(() => _group = value);
                await _load();
              },
            ),
            const SizedBox(height: 14),
            if (_busy) const LinearProgressIndicator(),
            if (!_busy && providers.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No voucher providers are configured.'),
                ),
              ),
            if (!_busy && _provider == null && providers.isNotEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Select a voucher provider to manage voucher groups.',
                  ),
                ),
              ),
            for (final voucher in _vouchers) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: SelectableText(
                    voucher.username,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    [
                      if (voucher.validity.isNotEmpty)
                        'Validity ${voucher.validity}',
                      if (voucher.expiry.isNotEmpty) 'Expiry ${voucher.expiry}',
                      if (voucher.used.isNotEmpty) voucher.used,
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'Expire',
                    onPressed: () => _expire(voucher),
                    icon: const Icon(Icons.timer_off_outlined),
                  ),
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

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

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
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

String _scalar(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String || value is num) return value.toString().trim();
  if (value is bool) return value ? '1' : '0';
  return fallback;
}

String _listText(dynamic value) {
  if (value == null) return '';
  if (value is String || value is num) return value.toString().trim();
  if (value is Iterable) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .join('\n');
  }
  return '';
}

String _normalizeLines(String value) {
  return value
      .split(RegExp(r'[,\n\r]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .join(',');
}

Set<String> _splitValues(String value) {
  return value
      .split(RegExp(r'[,\n\r]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();
}

bool _bool(dynamic value, bool fallback) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  if (const {'1', 'true', 'yes', 'on', 'enabled'}.contains(text)) return true;
  if (const {'0', 'false', 'no', 'off', 'disabled'}.contains(text)) return false;
  return fallback;
}
