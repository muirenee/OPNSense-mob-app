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

  test('extracts job id when JSON was returned as text', () {
    expect(
      DiagnosticsRepository.extractJobId(
        '{"result":"ok","uuid":"job-text-123"}',
      ),
      'job-text-123',
    );
  });

  test('recovers exactly one newly-created job id', () {
    expect(
      DiagnosticsRepository.findNewJobId(
        {'job-1', 'job-2'},
        {'job-1', 'job-2', 'job-3'},
      ),
      'job-3',
    );
    expect(
      DiagnosticsRepository.findNewJobId(
        {'job-1'},
        {'job-1', 'job-2', 'job-3'},
      ),
      isEmpty,
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

  test('ping payload nests model fields under settings', () {
    final payload = DiagnosticsRepository.buildPingPayload(
      '1.1.1.1',
      family: 'ip',
    );
    final ping = payload['ping'] as Map<String, dynamic>;
    final settings = ping['settings'] as Map<String, dynamic>;
    expect(settings['hostname'], '1.1.1.1');
    expect(settings['fam'], 'ip');
    expect(ping.containsKey('hostname'), isFalse);
  });

  test('traceroute payload nests model fields under settings', () {
    final payload = DiagnosticsRepository.buildTraceroutePayload(
      'example.com',
      family: 'inet6',
      protocol: 'icmp',
    );
    final traceroute = payload['traceroute'] as Map<String, dynamic>;
    final settings = traceroute['settings'] as Map<String, dynamic>;
    expect(settings['hostname'], 'example.com');
    expect(settings['ipproto'], 'inet6');
    expect(settings['protocol'], 'icmp');
  });

  test('packet capture payload uses official packetcapture model key', () {
    final payload = DiagnosticsRepository.buildPacketCapturePayload(
      interfaces: {'lan', 'wan'},
      family: 'ip',
      protocol: 'tcp',
      count: 25,
    );
    final capture = payload['packetcapture'] as Map<String, dynamic>;
    final settings = capture['settings'] as Map<String, dynamic>;
    expect(payload.containsKey('packet_capture'), isFalse);
    expect(settings['interface'], 'lan,wan');
    expect(settings['fam'], 'ip');
    expect(settings['protocol'], 'tcp');
    expect(settings['count'], '25');
  });

  test('extracts option settings from official packetcapture model', () {
    final settings = DiagnosticsRepository.extractSettings(
      {
        'packetcapture': {
          'settings': {
            'interface': {
              'wan': {'value': 'WAN', 'selected': 1},
            },
          },
        },
      },
      modelKey: 'packetcapture',
    );
    final choices = DiagnosticsRepository.settingChoices(settings, 'interface');
    expect(choices, hasLength(1));
    expect(choices.first.value, 'wan');
    expect(choices.first.label, 'WAN');
  });

  test('packet capture settings tolerate legacy underscored response key', () {
    final settings = DiagnosticsRepository.extractSettings(
      {
        'packet_capture': {
          'settings': {
            'interface': {
              'lan': {'value': 'LAN', 'selected': 1},
            },
          },
        },
      },
      modelKey: 'packetcapture',
    );
    final choices = DiagnosticsRepository.settingChoices(settings, 'interface');
    expect(choices.single.value, 'lan');
    expect(choices.single.label, 'LAN');
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
