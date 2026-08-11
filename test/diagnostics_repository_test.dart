import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/diagnostics/diagnostics_repository.dart';

void main() {
  test('parses routing table rows', () {
    final routes = DiagnosticsRepository.parseRoutes({
      'rows': [
        {
          'destination': '0.0.0.0/0',
          'gateway': '192.0.2.1',
          'interface': 'wan',
          'flags': 'UGS',
        },
      ],
    });
    expect(routes, hasLength(1));
    expect(routes.first.gateway, '192.0.2.1');
    expect(routes.first.interfaceName, 'wan');
  });

  test('extracts job id from nested API response', () {
    expect(
      DiagnosticsRepository.extractJobId({
        'result': {'uuid': 'job-123'},
      }),
      'job-123',
    );
  });

  test('parses packet capture job rows', () {
    final jobs = DiagnosticsRepository.parsePacketCaptureJobs({
      'rows': [
        {
          'uuid': 'capture-1',
          'status': 'running',
          'interface': 'wan',
          'count': '100',
        },
      ],
    });
    expect(jobs, hasLength(1));
    expect(jobs.first.id, 'capture-1');
    expect(jobs.first.interfaceName, 'wan');
  });
}
