class FirewallLogEntry {
  const FirewallLogEntry({
    required this.timestamp,
    required this.action,
    required this.interfaceName,
    required this.protocol,
    required this.source,
    required this.destination,
    this.sourcePort = '',
    this.destinationPort = '',
    this.label = '',
    this.ruleId = '',
  });

  final String timestamp;
  final String action;
  final String interfaceName;
  final String protocol;
  final String source;
  final String destination;
  final String sourcePort;
  final String destinationPort;
  final String label;
  final String ruleId;
}
