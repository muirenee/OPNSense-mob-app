class RouteEntry {
  const RouteEntry({
    required this.destination,
    required this.gateway,
    required this.interfaceName,
    required this.flags,
    this.family = '',
  });

  final String destination;
  final String gateway;
  final String interfaceName;
  final String flags;
  final String family;
}

class DiagnosticJob {
  const DiagnosticJob({
    required this.id,
    required this.status,
    this.description = '',
    this.output = '',
  });

  final String id;
  final String status;
  final String description;
  final String output;
}

class PacketCaptureJob {
  const PacketCaptureJob({
    required this.id,
    required this.status,
    this.interfaceName = '',
    this.description = '',
    this.count = '',
  });

  final String id;
  final String status;
  final String interfaceName;
  final String description;
  final String count;
}
