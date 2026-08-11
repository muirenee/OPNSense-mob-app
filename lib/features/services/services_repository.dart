import '../../core/api/opnsense_api_client.dart';
import 'services_models.dart';

enum ServiceAction { start, stop, restart }

class ServicesRepository {
  ServicesRepository(this.api);

  final OpnSenseApiClient api;

  Future<List<ServiceSummary>> load() async {
    final raw = await api.getData('/api/core/service/search');
    return parseServices(raw);
  }

  Future<void> perform(ServiceSummary service, ServiceAction action) async {
    final command = switch (action) {
      ServiceAction.start => 'start',
      ServiceAction.stop => 'stop',
      ServiceAction.restart => 'restart',
    };
    final path = StringBuffer('/api/core/service/$command/${Uri.encodeComponent(service.name)}');
    if (service.id.isNotEmpty) {
      path.write('/${Uri.encodeComponent(service.id)}');
    }
    await api.postData(path.toString());
  }

  static List<ServiceSummary> parseServices(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) {
      candidate = raw['rows'] ?? raw['items'] ?? raw['services'] ?? raw;
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
          row.putIfAbsent('name', () => entry.key.toString());
          rows.add(row);
        }
      }
    }

    final output = rows.map((row) {
      return ServiceSummary(
        name: _firstString(row, const ['name', 'service', 'service_name']),
        description: _firstString(
          row,
          const ['description', 'descr', 'title', 'display_name'],
        ),
        status: _firstString(
          row,
          const ['status', 'state', 'running', 'status_translated'],
        ),
        id: _firstString(row, const ['id', 'service_id', 'uuid']),
      );
    }).where((item) => item.name.isNotEmpty).toList();

    output.sort((a, b) {
      if (a.isRunning != b.isRunning) return a.isRunning ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return output;
  }

  static String _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }
}
