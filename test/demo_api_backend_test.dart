import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/core/api/demo_api_backend.dart';

void main() {
  const backend = DemoApiBackend();

  test('demo backend returns dashboard system information', () {
    final raw = backend.getData('/api/diagnostics/system/system_information');
    expect(raw, isA<Map>());
    final map = Map<String, dynamic>.from(raw as Map);
    expect(map['hostname'], 'sentinel-demo');
    expect(map['product_version'], '26.7.1');
  });

  test('demo backend provides representative services', () {
    final raw = backend.getData('/api/core/service/search');
    final rows = (raw as Map)['rows'] as List;
    expect(rows.length, greaterThanOrEqualTo(3));
  });

  test('demo mutations are simulated locally', () {
    final raw = backend.postData('/api/core/service/restart/unbound');
    expect(raw['status'], 'demo');
    expect(raw['result'], 'ok');
  });
}
