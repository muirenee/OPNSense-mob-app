class GatewaySummary {
  const GatewaySummary({
    required this.name,
    required this.status,
    this.interfaceName = '',
    this.address = '',
    this.monitor = '',
    this.delay = '',
    this.loss = '',
  });

  final String name;
  final String status;
  final String interfaceName;
  final String address;
  final String monitor;
  final String delay;
  final String loss;

  bool get isOnline {
    final value = status.toLowerCase();
    return value.contains('online') ||
        value.contains('up') ||
        value.contains('none');
  }
}

class NetworkInterfaceSummary {
  const NetworkInterfaceSummary({
    required this.identifier,
    required this.description,
    required this.status,
    required this.addresses,
    this.rxBytes,
    this.txBytes,
    this.rxPackets,
    this.txPackets,
    this.inputErrors,
    this.outputErrors,
    this.rxBitsPerSecond = 0,
    this.txBitsPerSecond = 0,
  });

  final String identifier;
  final String description;
  final String status;
  final List<String> addresses;
  final int? rxBytes;
  final int? txBytes;
  final int? rxPackets;
  final int? txPackets;
  final int? inputErrors;
  final int? outputErrors;
  final double rxBitsPerSecond;
  final double txBitsPerSecond;

  bool get isUp {
    final value = status.toLowerCase();
    return value.contains('up') ||
        value.contains('active') ||
        value.contains('running');
  }

  NetworkInterfaceSummary copyWith({
    int? rxBytes,
    int? txBytes,
    int? rxPackets,
    int? txPackets,
    int? inputErrors,
    int? outputErrors,
    double? rxBitsPerSecond,
    double? txBitsPerSecond,
  }) {
    return NetworkInterfaceSummary(
      identifier: identifier,
      description: description,
      status: status,
      addresses: addresses,
      rxBytes: rxBytes ?? this.rxBytes,
      txBytes: txBytes ?? this.txBytes,
      rxPackets: rxPackets ?? this.rxPackets,
      txPackets: txPackets ?? this.txPackets,
      inputErrors: inputErrors ?? this.inputErrors,
      outputErrors: outputErrors ?? this.outputErrors,
      rxBitsPerSecond: rxBitsPerSecond ?? this.rxBitsPerSecond,
      txBitsPerSecond: txBitsPerSecond ?? this.txBitsPerSecond,
    );
  }
}

class NetworkSnapshot {
  const NetworkSnapshot({
    required this.gateways,
    required this.interfaces,
  });

  final List<GatewaySummary> gateways;
  final List<NetworkInterfaceSummary> interfaces;
}
