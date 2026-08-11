class FirewallRuleSummary {
  const FirewallRuleSummary({
    required this.uuid,
    required this.action,
    required this.interfaceName,
    required this.protocol,
    required this.source,
    required this.destination,
    required this.description,
    required this.enabled,
    required this.logging,
    this.direction = '',
    this.sourcePort = '',
    this.destinationPort = '',
  });

  final String uuid;
  final String action;
  final String interfaceName;
  final String protocol;
  final String source;
  final String destination;
  final String description;
  final bool enabled;
  final bool logging;
  final String direction;
  final String sourcePort;
  final String destinationPort;
}
