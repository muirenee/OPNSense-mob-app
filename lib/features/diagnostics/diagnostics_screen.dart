
import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
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
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
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
  bool _busy = false;
  String _result = '';

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final host = _host.text.trim();
    if (host.isEmpty) return;
    setState(() {
      _busy = true;
      _result = 'Starting ping job…';
    });
    try {
      final created = await widget.repository.createPingJob(host);
      if (created.id.isEmpty) {
        setState(() => _result = created.output.isEmpty ? created.status : created.output);
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      final jobs = await widget.repository.loadPingJobs();
      final match = jobs.where((item) => item.id == created.id).toList();
      final job = match.isEmpty ? created : match.first;
      setState(() {
        _result = [
          'Job: ${created.id}',
          if (job.status.isNotEmpty) 'Status: ${job.status}',
          if (job.output.isNotEmpty) job.output,
        ].join('\n');
      });
    } catch (error) {
      setState(() => _result = 'Ping failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _ToolLayout(
        children: [
          TextField(
            controller: _host,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Host or IP address',
              prefixIcon: Icon(Icons.language),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _run,
            icon: const Icon(Icons.network_ping),
            label: Text(_busy ? 'Running…' : 'Run ping'),
          ),
          _OutputCard(text: _result),
        ],
      );
}

class _TracerouteTool extends StatefulWidget {
  const _TracerouteTool({required this.repository});
  final DiagnosticsRepository repository;
  @override
  State<_TracerouteTool> createState() => _TracerouteToolState();
}

class _TracerouteToolState extends State<_TracerouteTool> {
  final _host = TextEditingController(text: '1.1.1.1');
  bool _busy = false;
  String _result = '';

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_host.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final result = await widget.repository.runTraceroute(_host.text.trim());
      setState(() => _result = result.isEmpty ? 'Traceroute request completed.' : result);
    } catch (error) {
      setState(() => _result = 'Traceroute failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _ToolLayout(
        children: [
          TextField(
            controller: _host,
            decoration: const InputDecoration(
              labelText: 'Host or IP address',
              prefixIcon: Icon(Icons.alt_route),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _run,
            icon: const Icon(Icons.alt_route),
            label: Text(_busy ? 'Running…' : 'Run traceroute'),
          ),
          _OutputCard(text: _result),
        ],
      );
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
      setState(() => _result = DiagnosticsRepository.stringifyOutput(raw));
    } catch (error) {
      setState(() => _result = 'DNS lookup failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _ToolLayout(
        children: [
          TextField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: 'IP address for reverse lookup',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _run,
            icon: const Icon(Icons.search),
            label: const Text('Reverse lookup'),
          ),
          _OutputCard(text: _result),
        ],
      );
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
          return _ToolLayout(children: [
            Text('Routing table unavailable: ${snapshot.error}'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _refresh, child: const Text('Retry')),
          ]);
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
                              title: Text(routes[i].destination.isEmpty ? 'Route' : routes[i].destination),
                              subtitle: Text([
                                if (routes[i].gateway.isNotEmpty) 'via ${routes[i].gateway}',
                                if (routes[i].interfaceName.isNotEmpty) routes[i].interfaceName,
                                if (routes[i].flags.isNotEmpty) routes[i].flags,
                              ].join(' · ')),
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
  final _interface = TextEditingController(text: 'wan');
  final _host = TextEditingController();
  final _port = TextEditingController();
  bool _busy = false;
  late Future<List<PacketCaptureJob>> _future;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadPacketCaptureJobs();
  }

  @override
  void dispose() {
    _interface.dispose();
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.repository.loadPacketCaptureJobs());
    await _future;
  }

  Future<void> _start() async {
    if (_interface.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final job = await widget.repository.createPacketCapture(
        interfaceName: _interface.text.trim(),
        host: _host.text.trim(),
        port: _port.text.trim(),
      );
      setState(() => _message = job.id.isEmpty
          ? 'Capture response: ${job.status}'
          : 'Capture started: ${job.id}');
      await _refresh();
    } catch (error) {
      setState(() => _message = 'Capture failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop(PacketCaptureJob job) async {
    if (job.id.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.repository.stopPacketCapture(job.id);
      setState(() => _message = 'Capture ${job.id} stopped.');
      await _refresh();
    } catch (error) {
      setState(() => _message = 'Stop failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(PacketCaptureJob job) async {
    if (job.id.isEmpty) return;
    setState(() => _busy = true);
    try {
      final file = await widget.repository.downloadPacketCapture(job.id);
      setState(() => _message = 'PCAP saved to app temporary storage:\n${file.path}');
    } catch (error) {
      setState(() => _message = 'PCAP download failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PacketCaptureJob>>(
      future: _future,
      builder: (context, snapshot) {
        final jobs = snapshot.data ?? const <PacketCaptureJob>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _interface,
              decoration: const InputDecoration(
                labelText: 'Interface (for example wan, lan, igb0)',
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
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
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Port filter (optional)',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _start,
              icon: const Icon(Icons.fiber_manual_record),
              label: Text(_busy ? 'Working…' : 'Start capture'),
            ),
            if (_message.isNotEmpty) _OutputCard(text: _message),
            const SizedBox(height: 12),
            Text(
              'Capture jobs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (snapshot.hasError)
              Card(child: ListTile(title: const Text('Capture jobs unavailable'), subtitle: Text(snapshot.error.toString())))
            else if (jobs.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No packet capture jobs returned.')))
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < jobs.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text(jobs[i].description.isEmpty ? jobs[i].id : jobs[i].description),
                        subtitle: Text([
                          jobs[i].status,
                          if (jobs[i].interfaceName.isNotEmpty) jobs[i].interfaceName,
                          if (jobs[i].count.isNotEmpty) '${jobs[i].count} packets',
                        ].where((item) => item.isNotEmpty).join(' · ')),
                        trailing: PopupMenuButton<String>(
                          enabled: !_busy && jobs[i].id.isNotEmpty,
                          onSelected: (value) {
                            if (value == 'stop') _stop(jobs[i]);
                            if (value == 'download') _download(jobs[i]);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'stop', child: Text('Stop')),
                            PopupMenuItem(value: 'download', child: Text('Download PCAP')),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Captures default to 100 packets. Downloaded PCAP files are placed in app temporary storage.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

class _ToolLayout extends StatelessWidget {
  const _ToolLayout({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
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
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }
}
