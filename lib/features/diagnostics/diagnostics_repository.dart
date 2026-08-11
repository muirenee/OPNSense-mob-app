import 'dart:io';

import '../../core/api/api_choice.dart';
import '../../core/api/opnsense_api_client.dart';
import 'diagnostics_models.dart';

class DiagnosticsRepository {
  DiagnosticsRepository(this.api);

  final OpnSenseApiClient api;

  Future<List<RouteEntry>> loadRoutes() async {
    final raw = await api.getData('/api/diagnostics/interface/get_routes');
    return parseRoutes(raw);
  }

  Future<dynamic> reverseLookup(String address) async {
    return api.getData(
      '/api/diagnostics/dns/reverse_lookup',
      queryParameters: {'address': address},
    );
  }

  Future<Map<String, dynamic>> loadPacketCaptureSettings() async {
    final raw = await api.getData('/api/diagnostics/packet_capture/get');
    return extractSettings(raw, modelKey: 'packetcapture');
  }

  Future<String> runTraceroute(
    String host, {
    String protocol = 'udp',
    String family = 'inet',
    String sourceAddress = '',
  }) async {
    final raw = await api.postData(
      '/api/diagnostics/traceroute/set',
      data: buildTraceroutePayload(
        host,
        protocol: protocol,
        family: family,
        sourceAddress: sourceAddress,
      ),
    );
    ensureApiSuccess(raw, operation: 'Traceroute');

    if (raw is Map) {
      final response = raw['response'];
      if (response != null) {
        final output = formatTracerouteResponse(response);
        if (output.isNotEmpty) return output;
      }
      final nested = raw['traceroute'];
      if (nested is Map && nested['response'] != null) {
        final output = formatTracerouteResponse(nested['response']);
        if (output.isNotEmpty) return output;
      }
    }
    return 'Traceroute completed but returned no hop data.';
  }

  Future<DiagnosticJob> runPing(
    String host, {
    String family = 'ip',
    String sourceAddress = '',
    Duration sampleWindow = const Duration(seconds: 4),
  }) async {
    final created = await createPingJob(
      host,
      family: family,
      sourceAddress: sourceAddress,
    );
    if (created.id.isEmpty) {
      throw StateError('Ping API did not return a job UUID.');
    }

    await Future<void>.delayed(sampleWindow);

    try {
      await stopPing(created.id);
    } catch (_) {
      // Some firewall builds complete the short job before stop is requested.
    }

    final jobs = await loadPingJobs();
    DiagnosticJob result = created;
    for (final job in jobs) {
      if (job.id == created.id) {
        result = job;
        break;
      }
    }

    try {
      await removePing(created.id);
    } catch (_) {
      // Cleanup is best effort and should never hide valid statistics.
    }

    return result;
  }

  Future<DiagnosticJob> createPingJob(
    String host, {
    String family = 'ip',
    String sourceAddress = '',
  }) async {
    final raw = await api.postData(
      '/api/diagnostics/ping/set',
      data: buildPingPayload(
        host,
        family: family,
        sourceAddress: sourceAddress,
      ),
    );
    ensureApiSuccess(raw, operation: 'Create ping job');

    final id = extractJobId(raw);
    if (id.isEmpty) {
      throw StateError(
        'The firewall accepted the ping settings but returned no job UUID.',
      );
    }

    final started = await api.postData(
      '/api/diagnostics/ping/start/${Uri.encodeComponent(id)}',
    );
    ensureApiSuccess(started, operation: 'Start ping job');

    return DiagnosticJob(
      id: id,
      status: _statusFrom(started, fallback: 'running'),
      description: host,
    );
  }

  Future<List<DiagnosticJob>> loadPingJobs() async {
    final raw = await api.getData(
      '/api/diagnostics/ping/search_jobs',
      queryParameters: const {'current': 1, 'rowCount': 250},
    );
    return parseDiagnosticJobs(raw);
  }

  Future<void> stopPing(String jobId) async {
    final raw = await api.postData(
      '/api/diagnostics/ping/stop/${Uri.encodeComponent(jobId)}',
    );
    ensureApiSuccess(raw, operation: 'Stop ping job');
  }

  Future<void> removePing(String jobId) async {
    final raw = await api.postData(
      '/api/diagnostics/ping/remove/${Uri.encodeComponent(jobId)}',
    );
    ensureApiSuccess(raw, operation: 'Remove ping job');
  }

  Future<PacketCaptureJob> createPacketCapture({
    required Set<String> interfaces,
    String family = 'any',
    String protocol = 'any',
    String host = '',
    String port = '',
    int count = 100,
    bool promiscuous = false,
    bool invertProtocol = false,
    bool invertPort = false,
  }) async {
    if (interfaces.isEmpty) {
      throw StateError('Select at least one interface for packet capture.');
    }
    final raw = await api.postData(
      '/api/diagnostics/packet_capture/set',
      data: buildPacketCapturePayload(
        interfaces: interfaces,
        family: family,
        protocol: protocol,
        host: host,
        port: port,
        count: count,
        promiscuous: promiscuous,
        invertProtocol: invertProtocol,
        invertPort: invertPort,
      ),
    );
    ensureApiSuccess(raw, operation: 'Create packet capture');
    final id = extractJobId(raw);
    if (id.isEmpty) {
      throw StateError(
        'The firewall accepted packet-capture settings but returned no job UUID.',
      );
    }
    final started = await api.postData(
      '/api/diagnostics/packet_capture/start/${Uri.encodeComponent(id)}',
    );
    ensureApiSuccess(started, operation: 'Start packet capture');
    return PacketCaptureJob(
      id: id,
      status: _statusFrom(started, fallback: 'started'),
      interfaceName: interfaces.join(', '),
    );
  }

  Future<List<PacketCaptureJob>> loadPacketCaptureJobs() async {
    final raw = await api.getData('/api/diagnostics/packet_capture/search_jobs');
    return parsePacketCaptureJobs(raw);
  }

  Future<void> stopPacketCapture(String jobId) async {
    final raw = await api.postData(
      '/api/diagnostics/packet_capture/stop/${Uri.encodeComponent(jobId)}',
    );
    ensureApiSuccess(raw, operation: 'Stop packet capture');
  }

  Future<void> removePacketCapture(String jobId) async {
    final raw = await api.postData(
      '/api/diagnostics/packet_capture/remove/${Uri.encodeComponent(jobId)}',
    );
    ensureApiSuccess(raw, operation: 'Remove packet capture');
  }

  Future<File> downloadPacketCapture(String jobId) async {
    final bytes = await api.getBytes(
      '/api/diagnostics/packet_capture/download/${Uri.encodeComponent(jobId)}',
    );
    final safeId = jobId.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final file = File(
      '${Directory.systemTemp.path}/netsource_sentinel_capture_$safeId.pcap',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Map<String, dynamic> buildPingPayload(
    String host, {
    String family = 'ip',
    String sourceAddress = '',
    String packetSize = '56',
    String interval = '1',
    bool disableFragmentation = false,
  }) {
    return {
      'ping': {
        'settings': {
          'hostname': host,
          'fam': family,
          'source_address': sourceAddress,
          'packetsize': packetSize,
          'disable_frag': disableFragmentation ? '1' : '0',
          'interval': interval,
          'description': 'Netsource Sentinel',
        },
      },
    };
  }

  static Map<String, dynamic> buildTraceroutePayload(
    String host, {
    String protocol = 'udp',
    String family = 'inet',
    String sourceAddress = '',
  }) {
    return {
      'traceroute': {
        'settings': {
          'hostname': host,
          'ipproto': family,
          'protocol': protocol,
          'source_address': sourceAddress,
        },
      },
    };
  }

  static Map<String, dynamic> buildPacketCapturePayload({
    required Set<String> interfaces,
    String family = 'any',
    String protocol = 'any',
    String host = '',
    String port = '',
    int count = 100,
    bool promiscuous = false,
    bool invertProtocol = false,
    bool invertPort = false,
  }) {
    return {
      'packetcapture': {
        'settings': {
          'interface': encodeApiChoiceValues(interfaces),
          'description': 'Netsource Sentinel capture',
          'promiscuous': promiscuous ? '1' : '0',
          'fam': family,
          'protocol_not': invertProtocol ? '1' : '0',
          'protocol': protocol,
          'host': host,
          'port_not': invertPort ? '1' : '0',
          'port': port,
          'snaplen': '262144',
          'count': count.toString(),
        },
      },
    };
  }

  static Map<String, dynamic> extractSettings(
    dynamic raw, {
    required String modelKey,
  }) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    dynamic candidate = map[modelKey] ??
        (modelKey == 'packetcapture' ? map['packet_capture'] : null) ??
        map;
    if (candidate is Map) {
      final model = Map<String, dynamic>.from(candidate);
      candidate = model['settings'] ?? model;
    }
    return candidate is Map
        ? Map<String, dynamic>.from(candidate)
        : <String, dynamic>{};
  }

  static List<ApiChoice> settingChoices(
    Map<String, dynamic> settings,
    String field,
  ) =>
      parseApiChoices(settings[field], scalarValuesSelected: false);

  static Set<String> selectedSettingChoices(
    Map<String, dynamic> settings,
    String field,
  ) =>
      parseApiChoices(settings[field])
          .where((choice) => choice.selected)
          .map((choice) => choice.value)
          .toSet();

  static String? selectedSettingChoice(
    Map<String, dynamic> settings,
    String field,
  ) {
    final choices = parseApiChoices(settings[field]);
    for (final choice in choices) {
      if (choice.selected) return choice.value;
    }
    final raw = settings[field];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  static List<RouteEntry> parseRoutes(dynamic raw) {
    final rows = extractRows(raw);
    return rows
        .map(
          (row) => RouteEntry(
            destination: firstString(
              row,
              const ['destination', 'network', 'dst', 'Destination'],
            ),
            gateway: firstString(row, const ['gateway', 'gw', 'Gateway']),
            interfaceName: firstString(
              row,
              const ['interface', 'interface_name', 'netif', 'Netif', 'if'],
            ),
            flags: firstString(row, const ['flags', 'Flags']),
            family: firstString(row, const ['family', 'af', 'proto']),
          ),
        )
        .where(
          (item) =>
              item.destination.isNotEmpty ||
              item.gateway.isNotEmpty ||
              item.interfaceName.isNotEmpty,
        )
        .toList();
  }

  static List<DiagnosticJob> parseDiagnosticJobs(dynamic raw) {
    return extractRows(raw).map((row) {
      final sent = firstString(
        row,
        const ['send', 'sent', 'transmitted', 'packets_sent'],
      );
      final received = firstString(
        row,
        const ['received', 'recv', 'packets_received'],
      );
      final loss = firstString(row, const ['loss', 'packet_loss']);
      final min = firstString(row, const ['min', 'minimum']);
      final avg = firstString(row, const ['avg', 'average']);
      final max = firstString(row, const ['max', 'maximum']);
      final lastError = firstString(
        row,
        const ['last_error', 'last-error', 'error'],
      );
      final rawStatus = firstString(row, const ['status', 'state']);
      final hasStats = sent.isNotEmpty || received.isNotEmpty || loss.isNotEmpty;
      final status = lastError.isNotEmpty
          ? 'error'
          : rawStatus.isNotEmpty
              ? rawStatus
              : hasStats
                  ? 'completed'
                  : 'running';

      final summary = <String>[
        if (sent.isNotEmpty || received.isNotEmpty)
          'Packets: ${sent.isEmpty ? '—' : sent} sent · ${received.isEmpty ? '—' : received} received',
        if (loss.isNotEmpty) 'Loss: ${_withPercent(loss)}',
        if (min.isNotEmpty || avg.isNotEmpty || max.isNotEmpty)
          'Latency: min ${_withMs(min)} · avg ${_withMs(avg)} · max ${_withMs(max)}',
        if (lastError.isNotEmpty) 'Error: $lastError',
      ];

      return DiagnosticJob(
        id: firstString(row, const ['uuid', 'id', 'jobid', 'job_id']),
        status: status,
        description: firstString(
          row,
          const ['description', 'descr', 'hostname', 'host'],
        ),
        output: summary.isNotEmpty
            ? summary.join('\n')
            : firstString(row, const ['output', 'message']),
      );
    }).toList();
  }

  static List<PacketCaptureJob> parsePacketCaptureJobs(dynamic raw) {
    return extractRows(raw).map((row) {
      return PacketCaptureJob(
        id: firstString(row, const ['uuid', 'id', 'jobid', 'job_id']),
        status: firstString(row, const ['status', 'state']),
        interfaceName: firstString(row, const ['interface', 'interfaces']),
        description: firstString(row, const ['description', 'descr']),
        count: firstString(row, const ['count', 'packets']),
      );
    }).toList();
  }

  static String extractJobId(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final result = map['result'];
      if (result is String &&
          const {'failed', 'ok', 'success'}.contains(result.toLowerCase())) {
        // A status word is never a job identifier.
      } else {
        final direct = firstString(
          map,
          const ['uuid', 'id', 'jobid', 'job_id'],
        );
        if (direct.isNotEmpty) return direct;
      }
      for (final value in map.values) {
        if (value is Map) {
          final nested = extractJobId(value);
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return '';
  }

  static void ensureApiSuccess(
    dynamic raw, {
    required String operation,
  }) {
    if (raw is! Map) return;
    final map = Map<String, dynamic>.from(raw);
    final result = map['result']?.toString().trim().toLowerCase();
    final status = map['status']?.toString().trim().toLowerCase();
    if (result == 'failed' || status == 'failed' || status == 'error') {
      final detail = _errorDetail(map);
      throw StateError(
        detail.isEmpty ? '$operation failed.' : '$operation failed: $detail',
      );
    }
  }

  static String formatTracerouteResponse(dynamic response) {
    if (response == null) return '';
    if (response is List) {
      final lines = <String>[];
      for (var i = 0; i < response.length; i++) {
        final row = response[i];
        if (row is Map) {
          final map = Map<String, dynamic>.from(row);
          final hop = firstString(map, const ['hop', 'ttl', 'id']);
          final host = firstString(
            map,
            const ['hostname', 'host', 'address', 'ip', 'addr'],
          );
          final asn = firstString(map, const ['asn', 'as']);
          final times = <String>[];
          for (final key in const [
            'rtt1',
            'rtt2',
            'rtt3',
            'time1',
            'time2',
            'time3',
            'ms',
            'rtt',
          ]) {
            final value = map[key];
            if (value != null && value.toString().trim().isNotEmpty) {
              times.add(_withMs(value.toString()));
            }
          }
          final extras = <String>[if (asn.isNotEmpty) 'AS$asn', ...times];
          final prefix = hop.isEmpty ? '${i + 1}' : hop;
          final destination = host.isEmpty ? _compactMap(map) : host;
          lines.add(
            '$prefix  $destination${extras.isEmpty ? '' : '  ${extras.join(' · ')}'}',
          );
        } else {
          final value = row.toString().trim();
          if (value.isNotEmpty) lines.add(value);
        }
      }
      return lines.join('\n');
    }
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      for (final key in const ['rows', 'items', 'data', 'response']) {
        if (map[key] is List) return formatTracerouteResponse(map[key]);
      }
      return _compactMap(map);
    }
    return response.toString().trim();
  }

  static List<Map<String, dynamic>> extractRows(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) {
      candidate = raw['rows'] ??
          raw['items'] ??
          raw['data'] ??
          raw['routes'] ??
          raw;
    }
    final rows = <Map<String, dynamic>>[];
    if (candidate is List) {
      for (final item in candidate) {
        if (item is Map) rows.add(Map<String, dynamic>.from(item));
      }
    } else if (candidate is Map) {
      for (final entry in candidate.entries) {
        if (entry.value is Map) {
          final row = Map<String, dynamic>.from(entry.value as Map);
          row.putIfAbsent('id', () => entry.key.toString());
          rows.add(row);
        }
      }
    }
    return rows;
  }

  static String firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String || value is num || value is bool) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  static String stringifyOutput(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    if (raw is num || raw is bool) return raw.toString();
    if (raw is List) {
      return raw
          .map(stringifyOutput)
          .where((item) => item.isNotEmpty)
          .join('\n');
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      for (final key in const ['response', 'output', 'message', 'hostname']) {
        if (map[key] != null) {
          final value = stringifyOutput(map[key]);
          if (value.isNotEmpty) return value;
        }
      }
      return map.entries
          .map((entry) => '${entry.key}: ${stringifyOutput(entry.value)}')
          .join('\n');
    }
    return raw.toString();
  }

  static String _statusFrom(dynamic raw, {required String fallback}) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final value = firstString(map, const ['status', 'state', 'result']);
      return value.isEmpty ? fallback : value;
    }
    return fallback;
  }

  static String _errorDetail(Map<String, dynamic> map) {
    final message = firstString(map, const ['message', 'error']);
    if (message.isNotEmpty) return message;
    final validations = map['validations'] ?? map['validation'];
    if (validations is Map) {
      final parts = <String>[];
      for (final entry in validations.entries) {
        final value = entry.value?.toString().trim() ?? '';
        if (value.isNotEmpty) parts.add('${entry.key}: $value');
      }
      return parts.join(' · ');
    }
    if (validations is List) {
      return validations.map((item) => item.toString()).join(' · ');
    }
    return '';
  }

  static String _withPercent(String value) {
    final text = value.trim();
    if (text.isEmpty) return '—';
    return text.endsWith('%') ? text : '$text%';
  }

  static String _withMs(String value) {
    final text = value.trim();
    if (text.isEmpty) return '—';
    final lower = text.toLowerCase();
    return lower.endsWith('ms') ? text : '$text ms';
  }

  static String _compactMap(Map<String, dynamic> map) {
    return map.entries
        .where((entry) {
          final value = entry.value;
          return value != null &&
              (value is String || value is num || value is bool) &&
              value.toString().trim().isNotEmpty;
        })
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' · ');
  }
}
