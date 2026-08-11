class FirewallAliasSummary {
  const FirewallAliasSummary({
    required this.uuid,
    required this.name,
    this.type = '',
    this.content = '',
    this.description = '',
    this.enabled = true,
  });

  final String uuid;
  final String name;
  final String type;
  final String content;
  final String description;
  final bool enabled;
}
