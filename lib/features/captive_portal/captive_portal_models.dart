class CaptivePortalZone {
  const CaptivePortalZone({
    required this.uuid,
    required this.zoneId,
    required this.description,
    this.interfaces = '',
    this.authServers = '',
    this.idleTimeout = '0',
    this.hardTimeout = '0',
    this.serverName = '',
    this.enabled = true,
    this.roaming = true,
    this.concurrentLogins = true,
  });

  final String uuid;
  final String zoneId;
  final String description;
  final String interfaces;
  final String authServers;
  final String idleTimeout;
  final String hardTimeout;
  final String serverName;
  final bool enabled;
  final bool roaming;
  final bool concurrentLogins;
}

class CaptivePortalSession {
  const CaptivePortalSession({
    required this.sessionId,
    this.zoneId = '',
    this.username = '',
    this.ip = '',
    this.mac = '',
    this.start = '',
    this.lastAccess = '',
    this.timeLeft = '',
    this.bytesIn = '',
    this.bytesOut = '',
  });

  final String sessionId;
  final String zoneId;
  final String username;
  final String ip;
  final String mac;
  final String start;
  final String lastAccess;
  final String timeLeft;
  final String bytesIn;
  final String bytesOut;
}

class CaptivePortalVoucher {
  const CaptivePortalVoucher({
    required this.username,
    this.password = '',
    this.validity = '',
    this.expiry = '',
    this.used = '',
  });

  final String username;
  final String password;
  final String validity;
  final String expiry;
  final String used;
}
