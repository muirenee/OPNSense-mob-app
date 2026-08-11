class DhcpLeaseSummary {
  const DhcpLeaseSummary({
    required this.ip,
    this.mac = '',
    this.hostname = '',
    this.interfaceName = '',
    this.state = '',
    this.starts = '',
    this.ends = '',
    this.source = 'Kea',
    this.clientId = '',
    this.subnetId = '',
  });

  final String ip;
  final String mac;
  final String hostname;
  final String interfaceName;
  final String state;
  final String starts;
  final String ends;
  final String source;
  final String clientId;
  final String subnetId;

  bool get isActive {
    final value = state.toLowerCase();
    if (value.isEmpty) return true;
    return value.contains('active') ||
        value.contains('default') ||
        value.contains('assigned') ||
        value.contains('bound');
  }
}

class KeaSubnetSummary {
  const KeaSubnetSummary({
    required this.uuid,
    required this.subnet,
    this.description = '',
    this.subnetId = '',
  });

  final String uuid;
  final String subnet;
  final String description;
  final String subnetId;

  String get label => description.isEmpty ? subnet : '$subnet · $description';
}

class KeaReservationSummary {
  const KeaReservationSummary({
    required this.uuid,
    required this.subnetUuid,
    this.subnetLabel = '',
    this.ip = '',
    this.mac = '',
    this.clientId = '',
    this.hostname = '',
    this.description = '',
  });

  final String uuid;
  final String subnetUuid;
  final String subnetLabel;
  final String ip;
  final String mac;
  final String clientId;
  final String hostname;
  final String description;

  bool matchesLease(DhcpLeaseSummary lease) {
    final a = mac.replaceAll('-', ':').toLowerCase();
    final b = lease.mac.replaceAll('-', ':').toLowerCase();
    if (a.isNotEmpty && b.isNotEmpty && a == b) return true;
    if (ip.isNotEmpty && lease.ip.isNotEmpty && ip == lease.ip) return true;
    if (clientId.isNotEmpty &&
        lease.clientId.isNotEmpty &&
        clientId.toLowerCase() == lease.clientId.toLowerCase()) {
      return true;
    }
    return false;
  }
}

class KeaReservationDraft {
  const KeaReservationDraft({
    required this.subnetUuid,
    required this.ip,
    this.mac = '',
    this.clientId = '',
    this.hostname = '',
    this.description = '',
  });

  final String subnetUuid;
  final String ip;
  final String mac;
  final String clientId;
  final String hostname;
  final String description;

  Map<String, dynamic> toApi() => {
        'subnet': subnetUuid,
        'ip_address': ip.trim(),
        'hw_address': mac.trim(),
        'client_id': clientId.trim(),
        'hostname': hostname.trim(),
        'description': description.trim(),
      };
}

class KeaDhcpData {
  const KeaDhcpData({
    required this.leases,
    required this.reservations,
    required this.subnets,
  });

  final List<DhcpLeaseSummary> leases;
  final List<KeaReservationSummary> reservations;
  final List<KeaSubnetSummary> subnets;
}
