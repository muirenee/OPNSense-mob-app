class DashboardSnapshot {
  const DashboardSnapshot({
    required this.systemInformation,
    required this.memory,
    required this.disk,
    required this.interfaces,
  });

  final Map<String, dynamic> systemInformation;
  final Map<String, dynamic> memory;
  final Map<String, dynamic> disk;
  final List<InterfaceSummary> interfaces;
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
