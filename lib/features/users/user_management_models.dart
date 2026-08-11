class FirewallUserSummary {
  const FirewallUserSummary({
    required this.uuid,
    required this.name,
    this.description = '',
    this.email = '',
    this.scope = 'user',
    this.disabled = false,
    this.isAdmin = false,
    this.comment = '',
  });

  final String uuid;
  final String name;
  final String description;
  final String email;
  final String scope;
  final bool disabled;
  final bool isAdmin;
  final String comment;

  bool get isSystem => scope.toLowerCase() == 'system';
}

class FirewallGroupSummary {
  const FirewallGroupSummary({
    required this.uuid,
    required this.name,
    this.description = '',
    this.scope = 'user',
    this.member = '',
    this.privileges = '',
    this.sourceNetworks = '',
  });

  final String uuid;
  final String name;
  final String description;
  final String scope;
  final String member;
  final String privileges;
  final String sourceNetworks;

  bool get isSystem => scope.toLowerCase() == 'system';
}

class GeneratedApiKey {
  const GeneratedApiKey({
    required this.key,
    required this.secret,
    this.hostname = '',
  });

  final String key;
  final String secret;
  final String hostname;
}
