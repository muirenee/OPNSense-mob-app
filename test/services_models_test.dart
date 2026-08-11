import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/services/services_models.dart';

void main() {
  test('normalizes numeric running status', () {
    const service = ServiceSummary(name: 'configd', status: '1');

    expect(service.statusKind, ServiceStatusKind.running);
    expect(service.isRunning, isTrue);
    expect(service.statusLabel, 'Running');
  });

  test('normalizes stopped status', () {
    const service = ServiceSummary(name: 'example', status: '0');

    expect(service.statusKind, ServiceStatusKind.stopped);
    expect(service.isStopped, isTrue);
    expect(service.statusLabel, 'Stopped');
  });

  test('preserves non-standard service status', () {
    const service = ServiceSummary(name: 'example', status: 'degraded');

    expect(service.statusKind, ServiceStatusKind.other);
    expect(service.statusLabel, 'degraded');
  });

  test('uses description as display name when available', () {
    const service = ServiceSummary(
      name: 'dpinger',
      status: 'running',
      description: 'Gateway Watcher',
    );

    expect(service.displayName, 'Gateway Watcher');
  });
}
