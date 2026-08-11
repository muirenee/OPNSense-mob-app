import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/core/api/opnsense_api_client.dart';

void main() {
  test('normalizes firewall URL', () {
    expect(
      OpnSenseApiClient.normalizeBaseUrl('192.168.1.1/'),
      'https://192.168.1.1',
    );
    expect(
      OpnSenseApiClient.normalizeBaseUrl('https://fw.example.test///'),
      'https://fw.example.test',
    );
  });
}
