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

  Future<String> runTraceroute(String host) async {
    final raw = await api.postData(
      '/api/diagnostics/traceroute/set',
      data: {
        'traceroute': {
          'hostname': host,
          'ipproto': 'inet',
          'protocol': 'icmp',
          'source_address': '',
        },
      },
    );
    return stringifyOutput(raw);
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
          'description': 'Netsource OPN Manager',
        },
      },
    );
    final id = extractJobId(raw);
    if (id.isEmpty) {
      return DiagnosticJob(
        id: '',
        status: 'created',
        output: stringifyOutput(raw),
      );
    }
    await api.postData('/api/diagnostics/ping/start/${Uri.encodeComponent(id)}');
    return DiagnosticJob(id: id, status: 'started');
  }

  Future<List<DiagnosticJob>> loadPingJobs() async {
    final raw = await api.getData('/api/diagnostics/ping/search_jobs');
    return parseDiagnosticJobs(raw);
  }

  Future<void> stopPing(String jobId) async {
    await api.postData('/api/diagnostics/ping/stop/${Uri.encodeComponent(jobId)}');
  }

  Future<void> removePing(String jobId) async {
    await api.postData('/api/diagnostics/ping/remove/${Uri.encodeComponent(jobId)}');
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
          'description': 'Netsource OPN Manager capture',
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
    final id = extractJobId(raw);
    if (id.isEmpty) {
      return PacketCaptureJob(id: '', status: stringifyOutput(raw));
    }
    await api.postData(
      '/api/diagnostics/packet_capture/start/${Uri.encodeComponent(id)}',
    );
    return PacketCaptureJob(id: id, status: 'started', interfaceName: interfaceName);
  }

  Future<List<PacketCaptureJob>> loadPacketCaptureJobs() async {
    final raw = await api.getData('/api/diagnostics/packet_capture/search_jobs');
    return parsePacketCaptureJobs(raw);
  }

  Future<void> stopPacketCapture(String jobId) async {
    await api.postData(
      '/api/diagnostics/packet_capture/stop/${Uri.encodeComponent(jobId)}',
    );
  }

  Future<void> removePacketCapture(String jobId) async {
    await api.postData(
      '/api/diagnostics/packet_capture/remove/${Uri.encodeComponent(jobId)}',
    );
  }

  Future<File> downloadPacketCapture(String jobId) async {
    final bytes = await api.getBytes(
      '/api/diagnostics/packet_capture/download/${Uri.encodeComponent(jobId)}',
    );
    final safeId = jobId.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final file = File('${Directory.systemTemp.path}/opnsense_capture_$safeId.pcap');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static List<RouteEntry> parseRoutes(dynamic raw) {
    final rows = extractRows(raw);
    final output = rows.map((row) {
      return RouteEntry(
        destination: firstString(row, const [
          'destination', 'network', 'dst', 'Destination'
        ]),
        gateway: firstString(row, const ['gateway', 'gw', 'Gateway']),
        interfaceName: firstString(row, const [
          'interface', 'interface_name', 'netif', 'Netif', 'if'
        ]),
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
      return DiagnosticJob(
        id: firstString(row, const ['uuid', 'id', 'jobid', 'job_id']),
        status: firstString(row, const ['status', 'state', 'result']),
        description: firstString(row, const ['description', 'descr', 'hostname']),
        output: firstString(row, const ['output', 'result', 'message']),
      );
    }).toList();
  }

  static List<PacketCaptureJob> parsePacketCaptureJobs(dynamic raw) {
    return extractRows(raw).map((row) {
      return PacketCaptureJob(
        id: firstString(row, const ['uuid', 'id', 'jobid', 'job_id']),
        status: firstString(row, const ['status', 'state', 'result']),
        interfaceName: firstString(row, const ['interface', 'interfaces']),
        description: firstString(row, const ['description', 'descr']),
        count: firstString(row, const ['count', 'packets']),
      );
    }).toList();
  }

  static String extractJobId(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final direct = firstString(map, const [
        'uuid', 'id', 'jobid', 'job_id', 'result'
      ]);
      if (direct.isNotEmpty && !direct.contains(' ')) return direct;
      for (final value in map.values) {
        if (value is Map) {
          final nested = extractJobId(value);
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return '';
  }

  static List<Map<String, dynamic>> extractRows(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) {
      candidate = raw['rows'] ?? raw['items'] ?? raw['data'] ?? raw['routes'] ?? raw;
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
      return raw.map(stringifyOutput).where((item) => item.isNotEmpty).join('\n');
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      for (final key in const ['output', 'result', 'message', 'response']) {
        if (map[key] != null) {
          final value = stringifyOutput(map[key]);
          if (value.isNotEmpty) return value;
        }
      }
      return map.entries.map((entry) => '${entry.key}: ${stringifyOutput(entry.value)}').join('\n');
    }
    return raw.toString();
  }
}
