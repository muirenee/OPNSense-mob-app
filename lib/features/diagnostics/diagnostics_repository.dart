import 'dart:io';

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

  Future<String> runTraceroute(
    String host, {
    String protocol = 'udp',
    String family = 'inet',
  }) async {
    final raw = await api.postData(
      '/api/diagnostics/traceroute/set',
      data: {
        'traceroute': {
          'hostname': host,
          'ipproto': family,
          'protocol': protocol,
          'source_address': '',
        },
      },
    );
    ensureApiSuccess(raw, operation: 'Traceroute');

    if (raw is Map) {
      final response = raw['response'];
      if (response != null) {
        final output = formatTracerouteResponse(response);
        if (output.isNotEmpty) return output;
      }
    }
    return 'Traceroute completed but returned no hop data.';
  }

  Future<DiagnosticJob> runPing(
    String host, {
    Duration sampleWindow = const Duration(seconds: 4),
  }) async {
    final created = await createPingJob(host);
    if (created.id.isEmpty) {
      throw StateError('Ping API did not return a job UUID.');
    }

    await Future<void>.delayed(sampleWindow);

    try {
      await stopPing(created.id);
    } catch (_) {
      // The job may already have completed. Continue and collect statistics.
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
      // Cleanup is best effort and should not hide valid ping statistics.
    }

    return result;
  }

  Future<DiagnosticJob> createPingJob(String host) async {
    final raw = await api.postData(
      '/api/diagnostics/ping/set',
      data: {
        'ping': {
          'hostname': host,
          'fam': 'ip',
          'source_address': '',
          'packetsize': '56',
          'disable_frag': '0',
          'interval': '1',
          'description': 'Netsource Sentinel',
        },
      },
    );
    ensureApiSuccess(raw, operation: 'Create ping job');

    final id = extractJobId(raw);
    if (id.isEmpty) {
      throw StateError('The firewall accepted the ping request but returned no UUID.');
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
    required String interfaceName,
    String host = '',
    String port = '',
    int count = 100,
  }) async {
    final raw = await api.postData(
      '/api/diagnostics/packet_capture/set',
      data: {
        'packet_capture': {
          'interface': interfaceName,
          'description': 'Netsource Sentinel capture',
          'promiscuous': '0',
          'fam': 'any',
          'protocol_not': '0',
          'protocol': 'any',
          'host': host,
          'port_not': '0',
          'port': port,
          'snaplen': '262144',
          'count': count.toString(),
        },
      },
    );
    ensureApiSuccess(raw, operation: 'Create packet capture');
    final id = extractJobId(raw);
    if (id.isEmpty) {
      return PacketCaptureJob(id: '', status: stringifyOutput(raw));
    }
    final started = await api.postData(
      '/api/diagnostics/packet_capture/start/${Uri.encodeComponent(id)}',
    );
    ensureApiSuccess(started, operation: 'Start packet capture');
    return PacketCaptureJob(
      id: id,
      status: _statusFrom(started, fallback: 'started'),
      interfaceName: interfaceName,
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

  static List<RouteEntry> parseRoutes(dynamic raw) {
    final rows = extractRows(raw);
    final output = rows.map((row) {
      return RouteEntry(
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
      );
    }).where((item) =>
        item.destination.isNotEmpty ||
        item.gateway.isNotEmpty ||
        item.interfaceName.isNotEmpty).toList();
    return output;
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
      final direct = firstString(
        map,
        const ['uuid', 'id', 'jobid', 'job_id'],
      );
      if (direct.isNotEmpty) return direct;
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
    if (result == 'failed' || status == 'failed') {
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
          final extras = <String>[
            if (asn.isNotEmpty) 'AS$asn',
            ...times,
          ];
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
      return _compactMap(Map<String, dynamic>.from(response));
    }
    return response.toString().trim();
  }

  static List<Map<String, dynamic>> extractRows(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) {
      candidate =
          raw['rows'] ?? raw['items'] ?? raw['data'] ?? raw['routes'] ?? raw;
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
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
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
      for (final key in const ['response', 'output', 'message']) {
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
      return firstString(map, const ['status', 'state', 'result']).isEmpty
          ? fallback
          : firstString(map, const ['status', 'state', 'result']);
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
        .where((entry) => entry.value != null && entry.value.toString().isNotEmpty)
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' · ');
  }
}
