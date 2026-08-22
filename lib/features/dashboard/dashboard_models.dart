class DashboardSnapshot {
  const DashboardSnapshot({
    required this.systemInformation,
    required this.memory,
    required this.disk,
    required this.interfaces,
    required this.gateways,
  });

  final Map<String, dynamic> systemInformation;
  final Map<String, dynamic> memory;
  final Map<String, dynamic> disk;
  final List<InterfaceSummary> interfaces;
  final List<GatewaySummary> gateways;
}

class GatewaySummary {
  const GatewaySummary({
    required this.name,
    required this.interfaceName,
    required this.gateway,
    required this.monitor,
    required this.status,
    required this.delay,
    required this.loss,
    required this.description,
  });

  final String name;
  final String interfaceName;
  final String gateway;
  final String monitor;
  final String status;
  final String delay;
  final String loss;
  final String description;

  bool get isOffline {
    final value = status.toLowerCase();
    return value.contains('down') ||
        value.contains('offline') ||
        value.contains('loss') ||
        value.contains('unreachable');
  }

  bool get isOnline => !isOffline && status.toLowerCase() != 'unknown';
}

class InterfaceSummary {
  const InterfaceSummary({
    required this.identifier,
    required this.description,
    required this.status,
    required this.addresses,
  });

  final String identifier;
  final String description;
  final String status;
  final List<String> addresses;

  bool get isUp {
    final value = status.toLowerCase();
    return value.contains('up') || value.contains('active');
  }
}
