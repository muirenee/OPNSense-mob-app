enum NatRuleKind { portForward, outbound }

class NatRuleSummary {
  const NatRuleSummary({
    required this.uuid,
    required this.kind,
    this.interfaceName = '',
    this.protocol = '',
    this.source = '',
    this.sourcePort = '',
    this.destination = '',
    this.destinationPort = '',
    this.target = '',
    this.targetPort = '',
    this.description = '',
    this.enabled = true,
  });

  final String uuid;
  final NatRuleKind kind;
  final String interfaceName;
  final String protocol;
  final String source;
  final String sourcePort;
  final String destination;
  final String destinationPort;
  final String target;
  final String targetPort;
  final String description;
  final bool enabled;
}
