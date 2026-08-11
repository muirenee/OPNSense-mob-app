class NeighborSummary {
  const NeighborSummary({
    required this.ip,
    this.mac = '',
    this.hostname = '',
    this.interfaceName = '',
    this.type = '',
    this.status = '',
  });

  final String ip;
  final String mac;
  final String hostname;
  final String interfaceName;
  final String type;
  final String status;
}
