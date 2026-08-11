import 'opnsense_api_client.dart';
import 'opnsense_exception.dart';

enum ApiCapabilityState { available, forbidden, unavailable, error }

class ApiCapability {
  const ApiCapability({
    required this.id,
    required this.label,
    required this.path,
    required this.state,
    this.message,
  });

  final String id;
  final String label;
  final String path;
  final ApiCapabilityState state;
  final String? message;
}

class ApiCapabilityProbe {
  ApiCapabilityProbe(this.api);

  final OpnSenseApiClient api;

  static const probes = <({String id, String label, String path})>[
    (
      id: 'system',
      label: 'System diagnostics',
      path: '/api/diagnostics/system/system_information',
    ),
    (
      id: 'gateways',
      label: 'Gateway status',
      path: '/api/routes/gateway/status',
    ),
    (
      id: 'interfaces',
      label: 'Interface statistics',
      path: '/api/diagnostics/interface/get_interface_statistics',
    ),
    (
      id: 'services',
      label: 'Service status',
      path: '/api/core/service/search',
    ),
    (
      id: 'firewallRules',
      label: 'Firewall Automation rules',
      path: '/api/firewall/filter/searchRule',
    ),
    (
      id: 'firewallAliases',
      label: 'Firewall aliases',
      path: '/api/firewall/alias/searchItem',
    ),
    (
      id: 'portForward',
      label: 'NAT port forwards',
      path: '/api/firewall/d_nat/searchRule',
    ),
    (
      id: 'firewallStates',
      label: 'Firewall states',
      path: '/api/diagnostics/firewall/pf_states',
    ),
    (
      id: 'arp',
      label: 'ARP neighbors',
      path: '/api/diagnostics/interface/search_arp',
    ),
    (
      id: 'ndp',
      label: 'NDP neighbors',
      path: '/api/diagnostics/interface/search_ndp',
    ),
    (
      id: 'dnsmasqLeases',
      label: 'Dnsmasq DHCP leases',
      path: '/api/dnsmasq/leases/search',
    ),
    (
      id: 'keaLeases',
      label: 'Kea DHCPv4 leases',
      path: '/api/kea/leases4/search',
    ),
    (
      id: 'dhcpv4Leases',
      label: 'ISC DHCPv4 leases',
      path: '/api/dhcpv4/leases/searchLease',
    ),
    (
      id: 'wireguard',
      label: 'WireGuard service',
      path: '/api/wireguard/service/status',
    ),
    (
      id: 'openvpn',
      label: 'OpenVPN sessions',
      path: '/api/openvpn/service/search_sessions',
    ),
    (
      id: 'ipsec',
      label: 'IPsec service',
      path: '/api/ipsec/service/status',
    ),
    (
      id: 'ping',
      label: 'Ping diagnostics',
      path: '/api/diagnostics/ping/get',
    ),
    (
      id: 'traceroute',
      label: 'Traceroute diagnostics',
      path: '/api/diagnostics/traceroute/get',
    ),
    (
      id: 'routes',
      label: 'Routing table',
      path: '/api/diagnostics/interface/get_routes',
    ),
    (
      id: 'packetCapture',
      label: 'Packet capture',
      path: '/api/diagnostics/packet_capture/get',
    ),
  ];

  Future<List<ApiCapability>> run() async {
    final output = <ApiCapability>[];
    for (final probe in probes) {
      try {
        await api.getData(probe.path);
        output.add(
          ApiCapability(
            id: probe.id,
            label: probe.label,
            path: probe.path,
            state: ApiCapabilityState.available,
          ),
        );
      } on OpnSenseException catch (error) {
        final state = switch (error.statusCode) {
          403 => ApiCapabilityState.forbidden,
          404 => ApiCapabilityState.unavailable,
          _ => ApiCapabilityState.error,
        };
        output.add(
          ApiCapability(
            id: probe.id,
            label: probe.label,
            path: probe.path,
            state: state,
            message: error.message,
          ),
        );
      } catch (error) {
        output.add(
          ApiCapability(
            id: probe.id,
            label: probe.label,
            path: probe.path,
            state: ApiCapabilityState.error,
            message: error.toString(),
          ),
        );
      }
    }
    return output;
  }
}
