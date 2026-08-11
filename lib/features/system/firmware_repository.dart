import '../../core/api/opnsense_api_client.dart';

class FirmwareStatus {
  const FirmwareStatus({
    required this.status,
    required this.message,
    required this.updates,
    required this.downloadSize,
    required this.needsReboot,
    required this.raw,
  });

  final String status;
  final String message;
  final int updates;
  final String downloadSize;
  final bool needsReboot;
  final Map<String, dynamic> raw;

  bool get hasUpdates => status.toLowerCase() == 'ok' && updates > 0;
}

class FirmwareRepository {
  FirmwareRepository(this.api);
  final OpnSenseApiClient api;

  Future<FirmwareStatus> check() async {
    final raw = await api.getJson('/api/core/firmware/status');
    return FirmwareStatus(
      status: _text(raw['status']),
      message: _text(raw['status_msg'] ?? raw['message']),
      updates: _int(raw['updates']),
      downloadSize: _text(raw['download_size']),
      needsReboot: _truthy(raw['upgrade_needs_reboot']),
      raw: raw,
    );
  }

  Future<void> installUpdates() async {
    await api.postData('/api/core/firmware/update');
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static int _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(_text(value)) ?? 0;
  }

  static bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return const {'1', 'true', 'yes', 'on'}.contains(_text(value).toLowerCase());
  }
}
