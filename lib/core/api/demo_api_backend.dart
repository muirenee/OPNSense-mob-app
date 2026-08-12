class DemoApiBackend {
  const DemoApiBackend();

  dynamic getData(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    final normalized = path.toLowerCase();

    if (normalized.contains('/diagnostics/system/system_information')) {
      return {
        'hostname': 'sentinel-demo',
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
        'cpu': {'count': 4, 'model': 'Demo x86_64 CPU'},
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
        ],
      };
    }

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
        ],
      };
    }

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
            'name': 'ntpd',
            'description': 'Network Time',
            'status': 'running',
            'id': 'demo-ntpd',
          },
        ],
      };
    }

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
        ],
      };
    }

    if (normalized.contains('/captiveportal/settings/search')) {
      return {
        'rows': [
          {
            'uuid': 'demo-zone-guest',
            'description': 'Guest Wi-Fi',
            'zoneid': '1',
            'enabled': '1',
            'interfaces': 'opt1',
          },
        ],
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
          },
        ],
      };
    }

    if (normalized.contains('/diagnostics/interface/get_arp') ||
        normalized.contains('/diagnostics/interface/get_ndp')) {
      return {
        'rows': [
          {
            'ip-address': '10.10.100.25',
            'mac-address': '02:00:00:00:00:25',
            'interface': 'lan',
            'hostname': 'demo-workstation',
          },
        ],
      };
    }

    if (normalized.contains('/firewall/log')) {
      return {
        'rows': [
          {
            'action': 'pass',
            'interface': 'lan',
            'protocol': 'tcp',
            'src': '10.10.100.25',
            'dst': '198.51.100.20',
            'dstport': '443',
            'label': 'Default allow LAN',
          },
          {
            'action': 'block',
            'interface': 'wan',
            'protocol': 'tcp',
            'src': '198.51.100.41',
            'dst': '203.0.113.18',
            'dstport': '22',
            'label': 'Default deny',
          },
        ],
      };
    }

    if (normalized.contains('/firmware/status') ||
        normalized.contains('/firmware/info')) {
      return {
        'status': 'ok',
        'product_version': '26.7.1',
        'updates': [],
      };
    }

    // Most Sentinel repositories already handle empty search collections and
    // empty model maps gracefully. This keeps Demo Mode broad without faking
    // configuration values that could be mistaken for a real firewall.
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
    return <int>[];
  }
}
