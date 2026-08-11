class DhcpLeaseSummary {
  const DhcpLeaseSummary({
    required this.ip,
    this.mac = '',
    this.hostname = '',
    this.interfaceName = '',
    this.state = '',
    this.starts = '',
    this.ends = '',
    this.source = '',
  });

  final String ip;
  final String mac;
  final String hostname;
  final String interfaceName;
  final String state;
  final String starts;
  final String ends;
  final String source;
}
