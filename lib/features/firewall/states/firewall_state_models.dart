class FirewallStateSummary {
  const FirewallStateSummary({
    required this.id,
    this.creatorId = '',
    this.interfaceName = '',
    this.protocol = '',
    this.direction = '',
    this.source = '',
    this.destination = '',
    this.state = '',
    this.age = '',
    this.expires = '',
    this.packets = '',
    this.bytes = '',
  });

  final String id;
  final String creatorId;
  final String interfaceName;
  final String protocol;
  final String direction;
  final String source;
  final String destination;
  final String state;
  final String age;
  final String expires;
  final String packets;
  final String bytes;
}
