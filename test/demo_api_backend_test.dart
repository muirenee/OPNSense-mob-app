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
    expect(rows.length, greaterThanOrEqualTo(6));
  });

  test('demo backend populates network and gateway showcase data', () {
    final gateways = backend.getData('/api/routes/gateway/status') as Map;
    final traffic = backend.getData('/api/diagnostics/traffic/interface') as Map;
    expect((gateways['rows'] as List), isNotEmpty);
    expect((traffic['interfaces'] as Map).keys, containsAll(['wan', 'lan', 'opt1']));
  });

  test('demo backend populates firewall rules, states and logs', () {
    final rules = backend.getData('/api/firewall/filter/search_rule') as Map;
    final states = backend.postData('/api/diagnostics/firewall/query_states') as Map;
    final logs = backend.getData('/api/diagnostics/firewall/log') as Map;
    expect((rules['rows'] as List).length, greaterThanOrEqualTo(6));
    expect((states['rows'] as List), isNotEmpty);
    expect((logs['rows'] as List), isNotEmpty);
  });

  test('demo backend populates Kea DHCP showcase data', () {
    final leases = backend.getData('/api/kea/leases4/search') as Map;
    final reservations = backend.getData('/api/kea/dhcpv4/search_reservation') as Map;
    final subnets = backend.getData('/api/kea/dhcpv4/search_subnet') as Map;
    expect((leases['rows'] as List).length, greaterThanOrEqualTo(4));
    expect((reservations['rows'] as List), isNotEmpty);
    expect((subnets['rows'] as List), isNotEmpty);
  });

  test('demo backend populates captive portal showcase data', () {
    final zones = backend.getData('/api/captiveportal/settings/search_zones') as Map;
    final sessions = backend.getData('/api/captiveportal/session/search') as Map;
    final vouchers = backend.getData('/api/captiveportal/voucher/list_vouchers/demo/demo') as Map;
    expect((zones['rows'] as List).length, greaterThanOrEqualTo(2));
    expect((sessions['rows'] as List).length, greaterThanOrEqualTo(2));
    expect((vouchers['vouchers'] as List), isNotEmpty);
  });

  test('demo backend populates diagnostics and VPN data', () {
    final routes = backend.getData('/api/diagnostics/interface/get_routes') as Map;
    final ping = backend.getData('/api/diagnostics/ping/search_jobs') as Map;
    final wireguard = backend.getData('/api/wireguard/service/show') as Map;
    expect((routes['rows'] as List), isNotEmpty);
    expect((ping['rows'] as List), isNotEmpty);
    expect((wireguard['peers'] as List), isNotEmpty);
  });

  test('demo mutations are simulated locally', () {
    final raw = backend.postData('/api/core/service/restart/unbound');
    expect(raw['status'], 'demo');
    expect(raw['result'], 'ok');
  });
}
