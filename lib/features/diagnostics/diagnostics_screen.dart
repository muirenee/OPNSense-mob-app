import 'package:flutter/material.dart';

import '../../core/api/api_choice.dart';
import '../../core/api/opnsense_api_client.dart';
import '../../core/widgets/api_select_fields.dart';
import '../profiles/firewall_profile.dart';
import 'diagnostics_models.dart';
import 'diagnostics_repository.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    super.key,
    required this.profile,
    required this.credentials,
  });

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  late final DiagnosticsRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = DiagnosticsRepository(
      OpnSenseApiClient(
        profile: widget.profile,
        credentials: widget.credentials,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diagnostics'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Ping'),
              Tab(text: 'Traceroute'),
              Tab(text: 'DNS'),
              Tab(text: 'Routes'),
              Tab(text: 'Capture'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PingTool(repository: _repository),
            _TracerouteTool(repository: _repository),
            _DnsTool(repository: _repository),
            _RoutesTool(repository: _repository),
            _PacketCaptureTool(repository: _repository),
          ],
        ),
      ),
    );
  }
}

class _PingTool extends StatefulWidget {
  const _PingTool({required this.repository});

  final DiagnosticsRepository repository;

  @override
  State<_PingTool> createState() => _PingToolState();
}

class _PingToolState extends State<_PingTool> {
  final _host = TextEditingController(text: '1.1.1.1');
  final _source = TextEditingController();
  bool _busy = false;
  String _result = '';
  String _family = 'ip';

  @override
  void dispose() {
    _host.dispose();
    _source.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final host = _host.text.trim();
    if (host.isEmpty) return;

    setState(() {
      _busy = true;
      _result = 'Running ping…';
    });

    try {
      final job = await widget.repository.runPing(
        host,
        family: _family,
        sourceAddress: _source.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _result = [
          host,
          if (job.status.isNotEmpty) 'Status: ${job.status}',
          if (job.output.isNotEmpty) job.output,
        ].join('\n');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _result = 'Ping failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ToolLayout(
      children: [
        const _ToolIntro(
          icon: Icons.network_ping,
          title: 'Ping',
          text: 'Run a short reachability test from the firewall.',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _host,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Host or IP address',
            prefixIcon: Icon(Icons.language),
          ),
          onSubmitted: (_) {
            if (!_busy) _run();
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _family,
          decoration: const InputDecoration(
            labelText: 'Address family',
            prefixIcon: Icon(Icons.hub_outlined),
          ),
          items: const [
            DropdownMenuItem(value: 'ip', child: Text('IPv4')),
            DropdownMenuItem(value: 'ip6', child: Text('IPv6')),
          ],
          onChanged: _busy
              ? null
              : (value) {
                  if (value != null) setState(() => _family = value);
                },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _source,
          decoration: const InputDecoration(
            labelText: 'Source address (optional)',
            prefixIcon: Icon(Icons.call_made_outlined),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _run,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.network_ping),
          label: Text(_busy ? 'Running…' : 'Run ping'),
        ),
        _OutputCard(text: _result),
      ],
    );
  }
}

class _TracerouteTool extends StatefulWidget {
  const _TracerouteTool({required this.repository});

  final DiagnosticsRepository repository;

  @override
  State<_TracerouteTool> createState() => _TracerouteToolState();
}

class _TracerouteToolState extends State<_TracerouteTool> {
  final _host = TextEditingController(text: '1.1.1.1');
  final _source = TextEditingController();
  bool _busy = false;
  String _result = '';
  String _protocol = 'udp';
  String _family = 'inet';

  @override
  void dispose() {
    _host.dispose();
    _source.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final host = _host.text.trim();
    if (host.isEmpty) return;

    setState(() {
      _busy = true;
      _result = 'Running traceroute…';
    });

    try {
      final result = await widget.repository.runTraceroute(
        host,
        protocol: _protocol,
        family: _family,
        sourceAddress: _source.text.trim(),
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _result = 'Traceroute failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ToolLayout(
      children: [
        const _ToolIntro(
          icon: Icons.alt_route,
          title: 'Traceroute',
          text: 'Trace the network path from the firewall to a host.',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _host,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Host or IP address',
            prefixIcon: Icon(Icons.language),
          ),
          onSubmitted: (_) {
            if (!_busy) _run();
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _family,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Family'),
                items: const [
                  DropdownMenuItem(value: 'inet', child: Text('IPv4')),
                  DropdownMenuItem(value: 'inet6', child: Text('IPv6')),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null) setState(() => _family = value);
                      },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _protocol,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Protocol'),
                items: const [
                  DropdownMenuItem(value: 'udp', child: Text('UDP')),
                  DropdownMenuItem(value: 'icmp', child: Text('ICMP')),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null) setState(() => _protocol = value);
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _source,
          decoration: const InputDecoration(
            labelText: 'Source address (optional)',
            prefixIcon: Icon(Icons.call_made_outlined),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _run,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.alt_route),
          label: Text(_busy ? 'Running…' : 'Run traceroute'),
        ),
        _OutputCard(text: _result),
      ],
    );
  }
}

class _DnsTool extends StatefulWidget {
  const _DnsTool({required this.repository});

  final DiagnosticsRepository repository;

  @override
  State<_DnsTool> createState() => _DnsToolState();
}

class _DnsToolState extends State<_DnsTool> {
  final _address = TextEditingController();
  bool _busy = false;
  String _result = '';

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_address.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final raw = await widget.repository.reverseLookup(_address.text.trim());
      if (!mounted) return;
      setState(() => _result = DiagnosticsRepository.stringifyOutput(raw));
    } catch (error) {
      if (!mounted) return;
      setState(() => _result = 'DNS lookup failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ToolLayout(
      children: [
        const _ToolIntro(
          icon: Icons.dns_outlined,
          title: 'Reverse DNS',
          text: 'Look up the hostname associated with an IP address.',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _address,
          decoration: const InputDecoration(
            labelText: 'IP address',
            prefixIcon: Icon(Icons.dns_outlined),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _run,
          icon: const Icon(Icons.search),
          label: Text(_busy ? 'Looking up…' : 'Reverse lookup'),
        ),
        _OutputCard(text: _result),
      ],
    );
  }
}

class _RoutesTool extends StatefulWidget {
  const _RoutesTool({required this.repository});

  final DiagnosticsRepository repository;

  @override
  State<_RoutesTool> createState() => _RoutesToolState();
}

class _RoutesToolState extends State<_RoutesTool> {
  late Future<List<RouteEntry>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadRoutes();
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.repository.loadRoutes());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RouteEntry>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ToolLayout(
            children: [
              Text('Routing table unavailable: ${snapshot.error}'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          );
        }

        final normalized = _query.toLowerCase().trim();
        final routes = (snapshot.data ?? const <RouteEntry>[]).where((route) {
          if (normalized.isEmpty) return true;
          return route.destination.toLowerCase().contains(normalized) ||
              route.gateway.toLowerCase().contains(normalized) ||
              route.interfaceName.toLowerCase().contains(normalized);
        }).toList();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search routes',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Card(
                child: routes.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No routes returned.'),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < routes.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.route_outlined),
                              title: Text(
                                routes[i].destination.isEmpty
                                    ? 'Route'
                                    : routes[i].destination,
                              ),
                              subtitle: Text(
                                [
                                  if (routes[i].gateway.isNotEmpty)
                                    'via ${routes[i].gateway}',
                                  if (routes[i].interfaceName.isNotEmpty)
                                    routes[i].interfaceName,
                                  if (routes[i].flags.isNotEmpty) routes[i].flags,
                                ].join(' · '),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PacketCaptureTool extends StatefulWidget {
  const _PacketCaptureTool({required this.repository});

  final DiagnosticsRepository repository;

  @override
  State<_PacketCaptureTool> createState() => _PacketCaptureToolState();
}

class _PacketCaptureToolState extends State<_PacketCaptureTool> {
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _count = TextEditingController(text: '100');
  bool _busy = false;
  bool _settingsLoading = true;
  String _message = '';
  Object? _settingsError;
  List<ApiChoice> _interfaceChoices = const [];
  List<ApiChoice> _familyChoices = const [];
  List<ApiChoice> _protocolChoices = const [];
  Set<String> _interfaces = <String>{};
  String? _family = 'any';
  String? _protocol = 'any';
  bool _promiscuous = false;
  late Future<List<PacketCaptureJob>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadPacketCaptureJobs();
    _loadSettings();
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (mounted) {
      setState(() {
        _settingsLoading = true;
        _settingsError = null;
      });
    }
    try {
      final settings = await widget.repository.loadPacketCaptureSettings();
      final interfaces = DiagnosticsRepository.settingChoices(
        settings,
        'interface',
      );
      final families = DiagnosticsRepository.settingChoices(settings, 'fam');
      final protocols = DiagnosticsRepository.settingChoices(
        settings,
        'protocol',
      );
      final selectedInterfaces = DiagnosticsRepository.selectedSettingChoices(
        settings,
        'interface',
      );
      final selectedFamily = DiagnosticsRepository.selectedSettingChoice(
        settings,
        'fam',
      );
      final selectedProtocol = DiagnosticsRepository.selectedSettingChoice(
        settings,
        'protocol',
      );
      if (!mounted) return;
      setState(() {
        _interfaceChoices = interfaces;
        _familyChoices = families.isEmpty
            ? const [
                ApiChoice(value: 'any', label: 'Any'),
                ApiChoice(value: 'ip', label: 'IPv4'),
                ApiChoice(value: 'ip6', label: 'IPv6'),
                ApiChoice(value: 'arp', label: 'ARP'),
              ]
            : families;
        _protocolChoices = protocols.isEmpty
            ? const [
                ApiChoice(value: 'any', label: 'Any'),
                ApiChoice(value: 'tcp', label: 'TCP'),
                ApiChoice(value: 'udp', label: 'UDP'),
                ApiChoice(value: 'icmp', label: 'ICMP'),
              ]
            : protocols;
        _interfaces = selectedInterfaces;
        _family = selectedFamily ?? 'any';
        _protocol = selectedProtocol ?? 'any';
        _settingsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _settingsError = error;
        _settingsLoading = false;
        _familyChoices = const [
          ApiChoice(value: 'any', label: 'Any'),
          ApiChoice(value: 'ip', label: 'IPv4'),
          ApiChoice(value: 'ip6', label: 'IPv6'),
          ApiChoice(value: 'arp', label: 'ARP'),
        ];
        _protocolChoices = const [
          ApiChoice(value: 'any', label: 'Any'),
          ApiChoice(value: 'tcp', label: 'TCP'),
          ApiChoice(value: 'udp', label: 'UDP'),
          ApiChoice(value: 'icmp', label: 'ICMP'),
        ];
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.repository.loadPacketCaptureJobs());
    await Future.wait<dynamic>([_future, _loadSettings()]);
  }

  Future<void> _start() async {
    if (_interfaces.isEmpty) {
      _setMessage('Select at least one interface before starting capture.');
      return;
    }
    final count = int.tryParse(_count.text.trim()) ?? 100;
    if (count < 1) {
      _setMessage('Packet count must be at least 1.');
      return;
    }
    setState(() => _busy = true);
    try {
      final job = await widget.repository.createPacketCapture(
        interfaces: _interfaces,
        family: _family ?? 'any',
        protocol: _protocol ?? 'any',
        host: _host.text.trim(),
        port: _port.text.trim(),
        count: count,
        promiscuous: _promiscuous,
      );
      if (!mounted) return;
      setState(() => _message = 'Capture started: ${job.id}');
      await _refreshJobsOnly();
    } catch (error) {
      _setMessage('Capture failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshJobsOnly() async {
    setState(() => _future = widget.repository.loadPacketCaptureJobs());
    await _future;
  }

  Future<void> _stop(PacketCaptureJob job) async {
    if (job.id.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.repository.stopPacketCapture(job.id);
      _setMessage('Capture ${job.id} stopped.');
      await _refreshJobsOnly();
    } catch (error) {
      _setMessage('Stop failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(PacketCaptureJob job) async {
    if (job.id.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.repository.removePacketCapture(job.id);
      _setMessage('Capture ${job.id} removed.');
      await _refreshJobsOnly();
    } catch (error) {
      _setMessage('Remove failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(PacketCaptureJob job) async {
    if (job.id.isEmpty) return;
    setState(() => _busy = true);
    try {
      final file = await widget.repository.downloadPacketCapture(job.id);
      _setMessage('PCAP saved to app temporary storage:\n${file.path}');
    } catch (error) {
      _setMessage('PCAP download failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setMessage(String message) {
    if (mounted) setState(() => _message = message);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PacketCaptureJob>>(
      future: _future,
      builder: (context, snapshot) {
        final jobs = snapshot.data ?? const <PacketCaptureJob>[];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const _ToolIntro(
                icon: Icons.manage_search_outlined,
                title: 'Packet Capture',
                text: 'Capture traffic using the interfaces and protocol values exposed by the firewall API.',
              ),
              const SizedBox(height: 14),
              if (_settingsLoading) const LinearProgressIndicator(),
              if (_settingsError != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_outlined),
                    title: const Text('Capture options could not be loaded'),
                    subtitle: Text(_settingsError.toString()),
                    trailing: IconButton(
                      tooltip: 'Retry',
                      onPressed: _loadSettings,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
              ApiMultiSelectField(
                label: 'Interfaces',
                choices: _interfaceChoices,
                selected: _interfaces,
                prefixIcon: Icons.settings_ethernet,
                helperText: 'Select one or more interfaces returned by the firewall.',
                searchHint: 'Search interfaces',
                enabled: !_settingsLoading && _interfaceChoices.isNotEmpty,
                onChanged: (values) => setState(() => _interfaces = values),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ApiSingleSelectField(
                      label: 'Family',
                      choices: _familyChoices,
                      value: _family,
                      allowEmpty: false,
                      onChanged: (value) => setState(() => _family = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ApiSingleSelectField(
                      label: 'Protocol',
                      choices: _protocolChoices,
                      value: _protocol,
                      allowEmpty: false,
                      onChanged: (value) => setState(() => _protocol = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _host,
                decoration: const InputDecoration(
                  labelText: 'Host filter (optional)',
                  prefixIcon: Icon(Icons.filter_alt_outlined),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Port filter'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _count,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Packet count'),
                    ),
                  ),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Promiscuous mode'),
                value: _promiscuous,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _promiscuous = value),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy || _settingsLoading ? null : _start,
                icon: const Icon(Icons.fiber_manual_record),
                label: Text(_busy ? 'Working…' : 'Start capture'),
              ),
              if (_message.isNotEmpty) _OutputCard(text: _message),
              const SizedBox(height: 14),
              Text(
                'Capture jobs',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (snapshot.hasError)
                Card(
                  child: ListTile(
                    title: const Text('Capture jobs unavailable'),
                    subtitle: Text(snapshot.error.toString()),
                  ),
                )
              else if (jobs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No packet capture jobs returned.'),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < jobs.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          title: Text(
                            jobs[i].description.isEmpty
                                ? jobs[i].id
                                : jobs[i].description,
                          ),
                          subtitle: Text(
                            [
                              jobs[i].status,
                              if (jobs[i].interfaceName.isNotEmpty)
                                jobs[i].interfaceName,
                              if (jobs[i].count.isNotEmpty)
                                '${jobs[i].count} packets',
                            ].where((item) => item.isNotEmpty).join(' · '),
                          ),
                          trailing: PopupMenuButton<String>(
                            enabled: !_busy && jobs[i].id.isNotEmpty,
                            onSelected: (value) {
                              if (value == 'stop') _stop(jobs[i]);
                              if (value == 'download') _download(jobs[i]);
                              if (value == 'remove') _remove(jobs[i]);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'stop', child: Text('Stop')),
                              PopupMenuItem(
                                value: 'download',
                                child: Text('Download PCAP'),
                              ),
                              PopupMenuItem(value: 'remove', child: Text('Remove')),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolIntro extends StatelessWidget {
  const _ToolIntro({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
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
                text,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolLayout extends StatelessWidget {
  const _ToolLayout({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: children);
  }
}

class _OutputCard extends StatelessWidget {
  const _OutputCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', height: 1.45),
          ),
        ),
      ),
    );
  }
}
