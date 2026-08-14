class DemoApiBackend {
  const DemoApiBackend();

  dynamic getData(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    final normalized = path.toLowerCase();

    // Dashboard / system.
    if (normalized.contains('/diagnostics/system/system_information')) {
      return {
        'hostname': 'sentinel-demo',
        'domain': 'demo.netsource.local',
        'product_name': 'OPNsense',
        'product_version': '26.7.1',
        'platform': 'amd64',
        'uptime': '12 days 04:18:32',
      };
    }

    if (normalized.contains('/diagnostics/system/system_resources')) {
      return {
        'memory': {
          'total': 8589934592,
          'used': 3650722202,
          'total_frmt': '8192',
          'used_frmt': '3482',
          'free_frmt': '4710',
        },
        'loadavg': ['0.18', '0.24', '0.22'],
        'cpu': {
          'count': 4,
          'model': 'Demo x86_64 CPU',
          'usage': 23,
        },
      };
    }

    if (normalized.contains('/diagnostics/system/system_disk')) {
      return {
        'devices': [
          {
            'device': '/dev/gpt/rootfs',
            'mountpoint': '/',
            'type': 'ufs',
            'used': '6.8G',
            'available': '21.4G',
            'used_pct': 24,
          },
          {
            'device': '/dev/gpt/logs',
            'mountpoint': '/var/log',
            'type': 'ufs',
            'used': '1.2G',
            'available': '6.4G',
            'used_pct': 16,
          },
        ],
      };
    }

    // Interfaces, gateways and traffic.
    if (normalized.contains('/interfaces/overview/interfaces_info')) {
      return {
        'rows': [
          {
            'identifier': 'wan',
            'description': 'WAN',
            'status': 'up',
            'ipaddr': '203.0.113.18/30',
          },
          {
            'identifier': 'lan',
            'description': 'LAN',
            'status': 'up',
            'ipaddr': '10.10.100.1/24',
          },
          {
            'identifier': 'opt1',
            'description': 'Guest Wi-Fi',
            'status': 'up',
            'ipaddr': '10.10.200.1/24',
          },
          {
            'identifier': 'opt2',
            'description': 'Voice',
            'status': 'up',
            'ipaddr': '10.10.30.1/24',
          },
        ],
      };
    }

    if (normalized.contains('/routes/gateway/status')) {
      return {
        'rows': [
          {
            'name': 'WAN_PRIMARY',
            'status': 'online',
            'interface': 'WAN',
            'address': '203.0.113.17',
            'monitor': '1.1.1.1',
            'delay': '12.4 ms',
            'loss': '0.0%',
          },
          {
            'name': 'WAN_BACKUP',
            'status': 'online',
            'interface': 'WAN Backup',
            'address': '198.51.100.1',
            'monitor': '8.8.8.8',
            'delay': '18.7 ms',
            'loss': '0.0%',
          },
        ],
      };
    }

    if (normalized.contains('/diagnostics/traffic/interface')) {
      return {
        'interfaces': {
          'wan': {
            'name': 'WAN',
            'bytes received': 4817235120,
            'bytes transmitted': 1284320190,
            'packets received': 5849231,
            'packets transmitted': 3124088,
            'input errors': 0,
            'output errors': 0,
          },
          'lan': {
            'name': 'LAN',
            'bytes received': 7228040191,
            'bytes transmitted': 10492834560,
            'packets received': 9823510,
            'packets transmitted': 11840932,
            'input errors': 0,
            'output errors': 0,
          },
          'opt1': {
            'name': 'Guest Wi-Fi',
            'bytes received': 2119004880,
            'bytes transmitted': 3902550010,
            'packets received': 3320401,
            'packets transmitted': 4512201,
            'input errors': 0,
            'output errors': 0,
          },
          'opt2': {
            'name': 'Voice',
            'bytes received': 288503441,
            'bytes transmitted': 301882120,
            'packets received': 884203,
            'packets transmitted': 896811,
            'input errors': 0,
            'output errors': 0,
          },
        },
      };
    }

    // Services.
    if (normalized.contains('/core/service/search')) {
      return {
        'rows': [
          {
            'name': 'unbound',
            'description': 'Unbound DNS',
            'status': 'running',
            'id': 'demo-unbound',
          },
          {
            'name': 'kea-dhcp4',
            'description': 'Kea DHCPv4',
            'status': 'running',
            'id': 'demo-kea',
          },
          {
            'name': 'openvpn',
            'description': 'OpenVPN',
            'status': 'running',
            'id': 'demo-openvpn',
          },
          {
            'name': 'wireguard',
            'description': 'WireGuard',
            'status': 'running',
            'id': 'demo-wireguard',
          },
          {
            'name': 'strongswan',
            'description': 'IPsec / strongSwan',
            'status': 'running',
            'id': 'demo-ipsec',
          },
          {
            'name': 'ntpd',
            'description': 'Network Time',
            'status': 'running',
            'id': 'demo-ntpd',
          },
          {
            'name': 'captiveportal',
            'description': 'Captive Portal',
            'status': 'running',
            'id': 'demo-captiveportal',
          },
          {
            'name': 'netflow',
            'description': 'NetFlow Export',
            'status': 'stopped',
            'id': 'demo-netflow',
          },
        ],
      };
    }

    // Users and groups.
    if (normalized.contains('/auth/user/search')) {
      return {
        'rows': [
          {
            'uuid': 'demo-user-admin',
            'name': 'admin',
            'descr': 'Firewall administrator',
            'email': 'admin@example.invalid',
            'scope': 'system',
            'disabled': '0',
          },
          {
            'uuid': 'demo-user-noc',
            'name': 'noc.operator',
            'descr': 'NOC operator',
            'email': 'noc@example.invalid',
            'scope': 'user',
            'disabled': '0',
          },
          {
            'uuid': 'demo-user-helpdesk',
            'name': 'helpdesk',
            'descr': 'Guest Wi-Fi support',
            'email': 'helpdesk@example.invalid',
            'scope': 'user',
            'disabled': '0',
          },
        ],
      };
    }

    if (normalized.contains('/auth/group/search')) {
      return {
        'rows': [
          {
            'uuid': 'demo-group-admins',
            'name': 'admins',
            'description': 'Firewall administrators',
            'scope': 'system',
            'member': 'admin',
            'priv': 'page-all',
          },
          {
            'uuid': 'demo-group-noc',
            'name': 'noc',
            'description': 'Network operations',
            'scope': 'user',
            'member': 'noc.operator',
            'priv': 'page-dashboard-all,page-status-services',
          },
          {
            'uuid': 'demo-group-helpdesk',
            'name': 'helpdesk',
            'description': 'Captive portal support',
            'scope': 'user',
            'member': 'helpdesk',
            'priv': 'page-services-captiveportal',
          },
        ],
      };
    }

    // Firewall filter rules and references.
    if (normalized.contains('/firewall/filter/search_rule')) {
      return {
        'rows': [
          {
            'uuid': 'demo-rule-01',
            'action': 'pass',
            'interface': 'LAN',
            'direction': 'in',
            'protocol': 'TCP/UDP',
            'source_net': 'LAN net',
            'source_port': '',
            'destination_net': 'any',
            'destination_port': '',
            'description': 'Allow LAN to Internet',
            'enabled': '1',
          },
          {
            'uuid': 'demo-rule-02',
            'action': 'pass',
            'interface': 'Voice',
            'direction': 'in',
            'protocol': 'UDP',
            'source_net': '10.10.30.10',
            'source_port': '',
            'destination_net': 'any',
            'destination_port': '5060,10000-20000',
            'description': 'PBX SIP and RTP',
            'enabled': '1',
          },
          {
            'uuid': 'demo-rule-03',
            'action': 'pass',
            'interface': 'Guest Wi-Fi',
            'direction': 'in',
            'protocol': 'TCP',
            'source_net': 'Guest Wi-Fi net',
            'source_port': '',
            'destination_net': 'any',
            'destination_port': '80,443',
            'description': 'Guest web access',
            'enabled': '1',
          },
          {
            'uuid': 'demo-rule-04',
            'action': 'block',
            'interface': 'Guest Wi-Fi',
            'direction': 'in',
            'protocol': 'any',
            'source_net': 'Guest Wi-Fi net',
            'source_port': '',
            'destination_net': 'LAN net',
            'destination_port': '',
            'description': 'Isolate guests from LAN',
            'enabled': '1',
          },
          {
            'uuid': 'demo-rule-05',
            'action': 'pass',
            'interface': 'WAN',
            'direction': 'in',
            'protocol': 'UDP',
            'source_net': 'any',
            'source_port': '',
            'destination_net': 'WAN address',
            'destination_port': '51820',
            'description': 'WireGuard remote access',
            'enabled': '1',
          },
          {
            'uuid': 'demo-rule-06',
            'action': 'block',
            'interface': 'WAN',
            'direction': 'in',
            'protocol': 'any',
            'source_net': 'Q_FEEDS_MALWARE',
            'source_port': '',
            'destination_net': 'any',
            'destination_port': '',
            'description': 'Block threat feed sources',
            'enabled': '1',
          },
          {
            'uuid': 'demo-rule-07',
            'action': 'pass',
            'interface': 'LAN',
            'direction': 'in',
            'protocol': 'UDP',
            'source_net': 'LAN net',
            'source_port': '',
            'destination_net': 'This Firewall',
            'destination_port': '53',
            'description': 'Allow DNS to firewall',
            'enabled': '1',
          },
          {
            'uuid': 'demo-rule-08',
            'action': 'pass',
            'interface': 'LAN',
            'direction': 'in',
            'protocol': 'TCP',
            'source_net': '10.10.100.0/24',
            'source_port': '',
            'destination_net': '10.10.100.20',
            'destination_port': '443',
            'description': 'Management portal',
            'enabled': '0',
          },
        ],
      };
    }

    if (normalized.contains('/firewall/filter/get_interface_list')) {
      return {
        'groups': {
          'items': [
            {'value': 'lan_group', 'label': 'Internal networks'},
          ],
        },
        'interfaces': {
          'items': [
            {'value': 'wan', 'label': 'WAN'},
            {'value': 'lan', 'label': 'LAN'},
            {'value': 'opt1', 'label': 'Guest Wi-Fi'},
            {'value': 'opt2', 'label': 'Voice'},
          ],
        },
      };
    }

    if (normalized.contains('/firewall/filter/get_rule')) {
      return {
        'rule': {
          'enabled': '1',
          'action': 'pass',
          'interface': 'lan',
          'direction': 'in',
          'ipprotocol': 'inet',
          'protocol': 'TCP/UDP',
          'source_net': 'LAN net',
          'source_port': '',
          'destination_net': 'any',
          'destination_port': '',
          'description': 'Allow LAN to Internet',
        },
      };
    }

    if (normalized.contains('/diagnostics/firewall/log')) {
      return {
        'rows': [
          {
            '__timestamp__': '2026-08-14 21:33:18',
            'action': 'pass',
            'interface': 'lan',
            'protoname': 'TCP',
            'src': '10.10.100.25',
            'srcport': '51742',
            'dst': '198.51.100.20',
            'dstport': '443',
            'label': 'Allow LAN to Internet',
            'rid': '1000000101',
          },
          {
            '__timestamp__': '2026-08-14 21:33:15',
            'action': 'pass',
            'interface': 'opt1',
            'protoname': 'UDP',
            'src': '10.10.200.42',
            'srcport': '58612',
            'dst': '1.1.1.1',
            'dstport': '53',
            'label': 'Guest DNS',
            'rid': '1000000102',
          },
          {
            '__timestamp__': '2026-08-14 21:32:58',
            'action': 'block',
            'interface': 'wan',
            'protoname': 'TCP',
            'src': '198.51.100.41',
            'srcport': '39218',
            'dst': '203.0.113.18',
            'dstport': '22',
            'label': 'Default deny',
            'rid': '0',
          },
          {
            '__timestamp__': '2026-08-14 21:32:41',
            'action': 'pass',
            'interface': 'opt2',
            'protoname': 'UDP',
            'src': '10.10.30.10',
            'srcport': '5060',
            'dst': '192.0.2.50',
            'dstport': '5060',
            'label': 'PBX SIP and RTP',
            'rid': '1000000103',
          },
        ],
      };
    }

    // NAT.
    if (normalized.contains('/firewall/d_nat/search_rule')) {
      return {
        'rows': [
          {
            'uuid': 'demo-dnat-01',
            'interface': 'WAN',
            'protocol': 'TCP',
            'source_net': 'any',
            'destination_net': 'WAN address',
            'destination_port': '8443',
            'target': '10.10.100.20',
            'target_port': '443',
            'description': 'Remote management portal',
            'disabled': '0',
          },
          {
            'uuid': 'demo-dnat-02',
            'interface': 'WAN',
            'protocol': 'UDP',
            'source_net': 'any',
            'destination_net': 'WAN address',
            'destination_port': '51820',
            'target': '10.10.100.30',
            'target_port': '51820',
            'description': 'WireGuard gateway',
            'disabled': '0',
          },
        ],
      };
    }

    if (normalized.contains('/firewall/source_nat/search_rule')) {
      return {
        'rows': [
          {
            'uuid': 'demo-snat-01',
            'interface': 'WAN',
            'protocol': 'any',
            'source_net': '10.10.100.0/24',
            'destination_net': 'any',
            'target': 'Interface address',
            'description': 'LAN outbound NAT',
            'enabled': '1',
          },
          {
            'uuid': 'demo-snat-02',
            'interface': 'WAN',
            'protocol': 'any',
            'source_net': '10.10.200.0/24',
            'destination_net': 'any',
            'target': 'Interface address',
            'description': 'Guest outbound NAT',
            'enabled': '1',
          },
        ],
      };
    }

    if (normalized.contains('/firewall/d_nat/get_rule') ||
        normalized.contains('/firewall/source_nat/get_rule')) {
      return {
        'rule': {
          'enabled': '1',
          'interface': 'wan',
          'protocol': 'TCP',
          'source_net': 'any',
          'destination_net': 'WAN address',
          'destination_port': '8443',
          'target': '10.10.100.20',
          'target_port': '443',
          'description': 'Remote management portal',
        },
      };
    }

    // Kea DHCP.
    if (normalized.contains('/kea/leases4/search')) {
      return {
        'rows': [
          {
            'address': '10.10.100.25',
            'hw_address': '02:00:00:00:00:25',
            'hostname': 'ops-laptop',
            'interface': 'LAN',
            'state': 0,
            'expire': 1786759200,
            'client_id': '01:02:00:00:00:00:25',
            'subnet_id': '1',
          },
          {
            'address': '10.10.100.40',
            'hw_address': '02:00:00:00:00:40',
            'hostname': 'reception-pc',
            'interface': 'LAN',
            'state': 0,
            'expire': 1786757100,
            'subnet_id': '1',
          },
          {
            'address': '10.10.200.42',
            'hw_address': '02:00:00:00:10:42',
            'hostname': 'guest-phone',
            'interface': 'Guest Wi-Fi',
            'state': 0,
            'expire': 1786758000,
            'subnet_id': '2',
          },
          {
            'address': '10.10.200.57',
            'hw_address': '02:00:00:00:10:57',
            'hostname': 'guest-tablet',
            'interface': 'Guest Wi-Fi',
            'state': 0,
            'expire': 1786756200,
            'subnet_id': '2',
          },
          {
            'address': '10.10.30.10',
            'hw_address': '02:00:00:00:30:10',
            'hostname': 'voice-pbx',
            'interface': 'Voice',
            'state': 0,
            'expire': 1786760100,
            'subnet_id': '3',
          },
        ],
      };
    }

    if (normalized.contains('/kea/dhcpv4/search_subnet')) {
      return {
        'rows': [
          {
            'uuid': 'demo-subnet-lan',
            'subnet': '10.10.100.0/24',
            'description': 'LAN clients',
            'subnet_id': '1',
          },
          {
            'uuid': 'demo-subnet-guest',
            'subnet': '10.10.200.0/24',
            'description': 'Guest Wi-Fi clients',
            'subnet_id': '2',
          },
          {
            'uuid': 'demo-subnet-voice',
            'subnet': '10.10.30.0/24',
            'description': 'Voice devices',
            'subnet_id': '3',
          },
        ],
      };
    }

    if (normalized.contains('/kea/dhcpv4/search_reservation')) {
      return {
        'rows': [
          {
            'uuid': 'demo-res-pbx',
            'ip_address': '10.10.30.10',
            'hw_address': '02:00:00:00:30:10',
            'hostname': 'voice-pbx',
            'description': 'PBX server',
            'subnet': 'demo-subnet-voice',
          },
          {
            'uuid': 'demo-res-printer',
            'ip_address': '10.10.100.50',
            'hw_address': '02:00:00:00:00:50',
            'hostname': 'office-printer',
            'description': 'Reception printer',
            'subnet': 'demo-subnet-lan',
          },
        ],
      };
    }

    if (normalized.contains('/kea/dhcpv4/get_reservation')) {
      return {
        'reservation': {
          'ip_address': '10.10.30.10',
          'hw_address': '02:00:00:00:30:10',
          'hostname': 'voice-pbx',
          'description': 'PBX server',
          'subnet': 'demo-subnet-voice',
        },
      };
    }

    // Neighbors.
    if (normalized.contains('/diagnostics/interface/get_arp') ||
        normalized.contains('/diagnostics/interface/get_ndp')) {
      return {
        'rows': [
          {
            'ip-address': '10.10.100.25',
            'mac-address': '02:00:00:00:00:25',
            'interface': 'lan',
            'hostname': 'ops-laptop',
          },
          {
            'ip-address': '10.10.100.40',
            'mac-address': '02:00:00:00:00:40',
            'interface': 'lan',
            'hostname': 'reception-pc',
          },
          {
            'ip-address': '10.10.200.42',
            'mac-address': '02:00:00:00:10:42',
            'interface': 'opt1',
            'hostname': 'guest-phone',
          },
          {
            'ip-address': '10.10.30.10',
            'mac-address': '02:00:00:00:30:10',
            'interface': 'opt2',
            'hostname': 'voice-pbx',
          },
        ],
      };
    }

    // Diagnostics.
    if (normalized.contains('/diagnostics/interface/get_routes')) {
      return {
        'rows': [
          {
            'destination': 'default',
            'gateway': '203.0.113.17',
            'interface': 'wan',
            'flags': 'UGS',
            'family': 'inet',
          },
          {
            'destination': '10.10.100.0/24',
            'gateway': 'link#2',
            'interface': 'lan',
            'flags': 'U',
            'family': 'inet',
          },
          {
            'destination': '10.10.200.0/24',
            'gateway': 'link#3',
            'interface': 'opt1',
            'flags': 'U',
            'family': 'inet',
          },
          {
            'destination': '10.10.30.0/24',
            'gateway': 'link#4',
            'interface': 'opt2',
            'flags': 'U',
            'family': 'inet',
          },
        ],
      };
    }

    if (normalized.contains('/diagnostics/dns/reverse_lookup')) {
      return {
        'result': 'one.one.one.one',
        'address': queryParameters?['address'] ?? '1.1.1.1',
      };
    }

    if (normalized.contains('/diagnostics/ping/search_jobs')) {
      return {
        'rows': [
          {
            'uuid': 'demo-ping-job',
            'status': 'stopped',
            'description': '1.1.1.1',
            'sent': '4',
            'received': '4',
            'loss': '0',
            'min': '11.8',
            'avg': '12.4',
            'max': '13.1',
          },
        ],
      };
    }

    if (normalized.contains('/diagnostics/packet_capture/get')) {
      return {
        'packetcapture': {
          'settings': {
            'interface': {
              'lan': {'value': 'LAN', 'selected': 1},
              'wan': {'value': 'WAN', 'selected': 0},
              'opt1': {'value': 'Guest Wi-Fi', 'selected': 0},
              'opt2': {'value': 'Voice', 'selected': 0},
            },
            'fam': 'any',
            'protocol': 'any',
            'host': '',
            'port': '',
            'count': '100',
            'promiscuous': '0',
          },
        },
      };
    }

    if (normalized.contains('/diagnostics/packet_capture/search_jobs')) {
      return {
        'rows': [
          {
            'uuid': 'demo-capture-job',
            'status': 'completed',
            'interface': 'lan',
            'description': 'LAN HTTPS sample',
            'count': '48',
          },
        ],
      };
    }

    // Captive portal.
    if (normalized.contains('/captiveportal/settings/search_zones') ||
        normalized.contains('/captiveportal/settings/search')) {
      return {
        'rows': [
          {
            'uuid': 'demo-zone-guest',
            'description': 'Guest Wi-Fi',
            'zoneid': '1',
            'enabled': '1',
            'interfaces': 'opt1',
            'authservers': 'Local Database',
            'idletimeout': '30',
            'hardtimeout': '480',
            'servername': 'guest.portal.demo',
            'roaming': '1',
            'concurrentlogins': '1',
          },
          {
            'uuid': 'demo-zone-contractors',
            'description': 'Contractors',
            'zoneid': '2',
            'enabled': '1',
            'interfaces': 'lan',
            'authservers': 'Local Database',
            'idletimeout': '20',
            'hardtimeout': '240',
            'servername': 'contractors.portal.demo',
            'roaming': '0',
            'concurrentlogins': '1',
          },
        ],
      };
    }

    if (normalized.contains('/captiveportal/settings/get_zone')) {
      return {
        'zone': {
          'description': 'Guest Wi-Fi',
          'zoneid': '1',
          'enabled': '1',
          'interfaces': 'opt1',
          'authservers': 'Local Database',
          'idletimeout': '30',
          'hardtimeout': '480',
          'servername': 'guest.portal.demo',
          'roaming': '1',
          'concurrentlogins': '1',
        },
      };
    }

    if (normalized.contains('/captiveportal/session/zones')) {
      return {
        '1': 'Guest Wi-Fi',
        '2': 'Contractors',
      };
    }

    if (normalized.contains('/captiveportal/session/search')) {
      return {
        'rows': [
          {
            'sessionId': 'demo-session-1',
            'userName': 'guest-1042',
            'ipAddress': '10.10.200.42',
            'macAddress': '02:00:00:00:10:42',
            'zoneId': '1',
            'startTime': '2026-08-14 20:11:08',
            'lastAccess': '2026-08-14 21:34:10',
            'timeLeft': '06:36:58',
            'bytesIn': '148.2 MB',
            'bytesOut': '31.8 MB',
          },
          {
            'sessionId': 'demo-session-2',
            'userName': 'guest-1188',
            'ipAddress': '10.10.200.57',
            'macAddress': '02:00:00:00:10:57',
            'zoneId': '1',
            'startTime': '2026-08-14 20:42:33',
            'lastAccess': '2026-08-14 21:33:54',
            'timeLeft': '07:08:21',
            'bytesIn': '92.4 MB',
            'bytesOut': '18.1 MB',
          },
          {
            'sessionId': 'demo-session-3',
            'userName': 'contractor-07',
            'ipAddress': '10.10.100.72',
            'macAddress': '02:00:00:00:00:72',
            'zoneId': '2',
            'startTime': '2026-08-14 21:02:12',
            'lastAccess': '2026-08-14 21:32:44',
            'timeLeft': '03:29:28',
            'bytesIn': '41.6 MB',
            'bytesOut': '7.9 MB',
          },
        ],
      };
    }

    if (normalized.contains('/captiveportal/voucher/list_providers')) {
      return {
        'providers': ['Local Vouchers'],
      };
    }

    if (normalized.contains('/captiveportal/voucher/list_voucher_groups')) {
      return {
        'groups': ['Guests-8h', 'Visitors-2h'],
      };
    }

    if (normalized.contains('/captiveportal/voucher/list_vouchers')) {
      return {
        'vouchers': [
          {
            'username': 'GUEST-7K2M',
            'password': '934812',
            'validity': '480',
            'expiry': '2026-08-15 05:00',
            'used': 'active',
          },
          {
            'username': 'GUEST-P4Q8',
            'password': '182640',
            'validity': '480',
            'expiry': '2026-08-15 05:00',
            'used': 'unused',
          },
          {
            'username': 'GUEST-N6R1',
            'password': '570218',
            'validity': '120',
            'expiry': '2026-08-14 23:30',
            'used': 'unused',
          },
        ],
      };
    }

    // VPN.
    if (normalized.contains('/wireguard/service/status')) {
      return {
        'status': 'running',
        'message': 'WireGuard service is running',
      };
    }

    if (normalized.contains('/ipsec/service/status')) {
      return {
        'status': 'running',
        'message': 'IPsec service is running',
      };
    }

    if (normalized.contains('/wireguard/service/show')) {
      return {
        'peers': [
          {
            'id': 'wg-peer-1',
            'name': 'NOC Laptop',
            'status': 'connected',
            'endpoint': '198.51.100.44:51820',
            'allowed_ips': '10.50.0.2/32',
            'latest_handshake': '38 seconds ago',
            'bytes_received': '24.8 MB',
            'bytes_sent': '71.2 MB',
            'interface': 'wg0',
          },
          {
            'id': 'wg-peer-2',
            'name': 'Remote Branch',
            'status': 'connected',
            'endpoint': '192.0.2.88:51820',
            'allowed_ips': '10.60.0.0/24',
            'latest_handshake': '1 minute ago',
            'bytes_received': '318.4 MB',
            'bytes_sent': '612.7 MB',
            'interface': 'wg0',
          },
        ],
      };
    }

    if (normalized.contains('/openvpn/service/search_sessions')) {
      return {
        'rows': [
          {
            'id': 'ovpn-01',
            'common_name': 'support-engineer',
            'status': 'connected',
            'real_address': '198.51.100.72:51833',
            'virtual_address': '10.8.0.6',
            'connected_since': '2026-08-14 18:22:51',
            'bytes_received': '18.2 MB',
            'bytes_sent': '44.7 MB',
            'protocol': 'UDP',
          },
        ],
      };
    }

    if (normalized.contains('/ipsec/sessions/search_phase1')) {
      return {
        'rows': [
          {
            'id': 'ipsec-01',
            'name': 'Branch Office',
            'status': 'ESTABLISHED',
            'remote': '192.0.2.120',
            'virtual_address': '10.70.0.0/24',
            'connected_since': '2026-08-14 07:14:03',
            'bytes_received': '1.8 GB',
            'bytes_sent': '2.3 GB',
            'protocol': 'IKEv2',
          },
        ],
      };
    }

    // Firmware.
    if (normalized.contains('/firmware/status') ||
        normalized.contains('/firmware/info')) {
      return {
        'status': 'ok',
        'product_version': '26.7.1',
        'updates': [],
      };
    }

    // Generic fallback remains intentionally empty for modules that do not yet
    // have a showcase fixture. It prevents fake configuration from being
    // mistaken for a real firewall while keeping navigation stable.
    if (normalized.contains('/search') ||
        normalized.contains('/status') ||
        normalized.contains('/list')) {
      return {'rows': <Map<String, dynamic>>[]};
    }

    if (normalized.contains('/get')) return <String, dynamic>{};

    return <String, dynamic>{};
  }

  dynamic postData(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) {
    final normalized = path.toLowerCase();

    if (normalized.contains('/diagnostics/firewall/query_states')) {
      return {
        'rows': [
          {
            'id': '1000001',
            'creatorid': '123456789',
            'interface': 'lan',
            'proto': 'tcp',
            'direction': 'out',
            'src': '10.10.100.25:51742',
            'dst': '198.51.100.20:443',
            'state': 'ESTABLISHED:ESTABLISHED',
            'age': '00:06:14',
            'expires': '00:23:41',
            'packets': '182',
            'bytes': '184220',
          },
          {
            'id': '1000002',
            'creatorid': '123456789',
            'interface': 'opt1',
            'proto': 'udp',
            'direction': 'out',
            'src': '10.10.200.42:58612',
            'dst': '1.1.1.1:53',
            'state': 'MULTIPLE:MULTIPLE',
            'age': '00:00:11',
            'expires': '00:00:49',
            'packets': '4',
            'bytes': '612',
          },
          {
            'id': '1000003',
            'creatorid': '123456789',
            'interface': 'opt2',
            'proto': 'udp',
            'direction': 'out',
            'src': '10.10.30.10:5060',
            'dst': '192.0.2.50:5060',
            'state': 'MULTIPLE:MULTIPLE',
            'age': '01:22:04',
            'expires': '00:00:56',
            'packets': '943',
            'bytes': '74428',
          },
          {
            'id': '1000004',
            'creatorid': '123456789',
            'interface': 'wan',
            'proto': 'udp',
            'direction': 'in',
            'src': '198.51.100.44:51820',
            'dst': '203.0.113.18:51820',
            'state': 'MULTIPLE:MULTIPLE',
            'age': '00:41:09',
            'expires': '00:01:12',
            'packets': '3328',
            'bytes': '4820341',
          },
        ],
      };
    }

    if (normalized.contains('/diagnostics/traceroute/set')) {
      return {
        'result': 'ok',
        'status': 'demo',
        'response': [
          {
            'hop': '1',
            'hostname': '10.10.100.1',
            'rtt1': '0.7',
            'rtt2': '0.6',
            'rtt3': '0.8',
          },
          {
            'hop': '2',
            'hostname': '203.0.113.17',
            'rtt1': '3.4',
            'rtt2': '3.2',
            'rtt3': '3.3',
          },
          {
            'hop': '3',
            'hostname': '198.51.100.9',
            'rtt1': '8.6',
            'rtt2': '8.9',
            'rtt3': '8.7',
          },
          {
            'hop': '4',
            'hostname': 'one.one.one.one',
            'rtt1': '12.1',
            'rtt2': '12.4',
            'rtt3': '12.2',
          },
        ],
      };
    }

    if (normalized.contains('/diagnostics/ping/set')) {
      return {
        'result': 'ok',
        'status': 'demo',
        'uuid': 'demo-ping-job',
      };
    }

    if (normalized.contains('/diagnostics/packet_capture/set')) {
      return {
        'result': 'ok',
        'status': 'demo',
        'uuid': 'demo-capture-job',
      };
    }

    if (normalized.contains('/captiveportal/voucher/generate_vouchers')) {
      return {
        'result': 'ok',
        'status': 'demo',
        'vouchers': [
          {
            'username': 'DEMO-A1B2',
            'password': '482913',
            'validity': '${data?['validity'] ?? 120}',
            'expiry': 'demo',
            'used': 'unused',
          },
          {
            'username': 'DEMO-C3D4',
            'password': '731205',
            'validity': '${data?['validity'] ?? 120}',
            'expiry': 'demo',
            'used': 'unused',
          },
        ],
      };
    }

    return {
      'result': 'ok',
      'status': 'demo',
      'uuid': 'demo-${DateTime.now().millisecondsSinceEpoch}',
      'message': 'Demo Mode simulated this action; no firewall was changed.',
    };
  }

  List<int> getBytes(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    // Minimal PCAP global header followed by no packets. This is enough for the
    // Demo Mode download action to create a valid-looking capture file locally.
    if (path.toLowerCase().contains('/diagnostics/packet_capture/download/')) {
      return const [
        0xd4, 0xc3, 0xb2, 0xa1,
        0x02, 0x00, 0x04, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0xff, 0xff, 0x00, 0x00,
        0x01, 0x00, 0x00, 0x00,
      ];
    }
    return <int>[];
  }
}
