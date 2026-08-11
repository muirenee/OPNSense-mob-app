enum ServiceStatusKind { running, stopped, other }

class ServiceSummary {
  const ServiceSummary({
    required this.name,
    required this.status,
    this.description = '',
    this.id = '',
  });

  final String name;
  final String status;
  final String description;
  final String id;

  String get displayName => description.isEmpty ? name : description;

  ServiceStatusKind get statusKind {
    final value = status.trim().toLowerCase();

    if (value.contains('running') ||
        value.contains('started') ||
        value == '1' ||
        value == 'true' ||
        value == 'up' ||
        value == 'online') {
      return ServiceStatusKind.running;
    }

    if (value.contains('stopped') ||
        value.contains('stop') ||
        value.contains('inactive') ||
        value == '0' ||
        value == 'false' ||
        value == 'down' ||
        value == 'offline') {
      return ServiceStatusKind.stopped;
    }

    return ServiceStatusKind.other;
  }

  bool get isRunning => statusKind == ServiceStatusKind.running;

  bool get isStopped => statusKind == ServiceStatusKind.stopped;

  String get statusLabel {
    return switch (statusKind) {
      ServiceStatusKind.running => 'Running',
      ServiceStatusKind.stopped => 'Stopped',
      ServiceStatusKind.other => status.trim().isEmpty ? 'Unknown' : status.trim(),
    };
  }
}