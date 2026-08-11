enum VpnKind { wireGuard, openVpn, ipsec }

enum VpnServiceAction { start, stop, restart }

class VpnServiceStatus {
  const VpnServiceStatus({
    required this.kind,
    required this.label,
    required this.status,
    this.message = '',
  });

  final VpnKind kind;
  final String label;
  final String status;
  final String message;

  bool get isRunning {
    final value = status.toLowerCase();
    return value.contains('run') ||
        value.contains('up') ||
        value == '1' ||
        value == 'true' ||
        value == 'ok';
  }
}

class VpnSession {
  const VpnSession({
    required this.kind,
    required this.id,
    required this.name,
    required this.status,
    this.remote = '',
    this.virtualAddress = '',
    this.connectedSince = '',
    this.bytesIn = '',
    this.bytesOut = '',
    this.details = '',
  });

  final VpnKind kind;
  final String id;
  final String name;
  final String status;
  final String remote;
  final String virtualAddress;
  final String connectedSince;
  final String bytesIn;
  final String bytesOut;
  final String details;

  bool get isConnected {
    final value = status.toLowerCase();
    return value.contains('connect') ||
        value.contains('establish') ||
        value.contains('up') ||
        value.contains('online') ||
        value == '1' ||
        value == 'true';
  }
}
