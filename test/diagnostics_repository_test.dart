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

  test('never treats result failed as a job id', () {
    expect(
      DiagnosticsRepository.extractJobId({'result': 'failed'}),
      isEmpty,
    );
  });

  test('failed API result raises an operation error', () {
    expect(
      () => DiagnosticsRepository.ensureApiSuccess(
        {
          'result': 'failed',
          'validations': {'hostname': 'Host is required'},
        },
        operation: 'Ping',
      ),
      throwsA(
        predicate(
          (error) =>
              error is StateError &&
              error.toString().contains('Host is required'),
        ),
      ),
    );
  });

  test('parses ping statistics into readable output', () {
    final jobs = DiagnosticsRepository.parseDiagnosticJobs({
      'rows': [
        {
          'uuid': 'ping-1',
          'hostname': '1.1.1.1',
          'send': '4',
          'received': '4',
          'loss': '0',
          'min': '10.1',
          'avg': '12.2',
          'max': '15.3',
        },
      ],
    });

    expect(jobs, hasLength(1));
    expect(jobs.first.id, 'ping-1');
    expect(jobs.first.status, 'completed');
    expect(jobs.first.output, contains('4 sent'));
    expect(jobs.first.output, contains('4 received'));
    expect(jobs.first.output, contains('Loss: 0%'));
    expect(jobs.first.output, contains('avg 12.2 ms'));
  });

  test('formats traceroute response hops', () {
    final output = DiagnosticsRepository.formatTracerouteResponse([
      {
        'hop': '1',
        'address': '192.0.2.1',
        'rtt1': '1.2',
        'rtt2': '1.4',
      },
      {
        'hop': '2',
        'hostname': 'example.net',
        'rtt1': '10.0',
      },
    ]);

    expect(output, contains('1  192.0.2.1'));
    expect(output, contains('1.2 ms'));
    expect(output, contains('2  example.net'));
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
