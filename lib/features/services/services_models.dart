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

  bool get isRunning {
    final value = status.toLowerCase();
    return value.contains('running') ||
        value.contains('started') ||
        value == '1' ||
        value == 'true';
  }
}
