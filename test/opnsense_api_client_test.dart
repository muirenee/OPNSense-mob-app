import 'dart:convert';

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

  test('serializes an empty POST as a real JSON object', () {
    expect(OpnSenseApiClient.encodePostBody(null), '{}');
    expect(OpnSenseApiClient.encodePostBody(const <String, dynamic>{}), '{}');
  });

  test('serializes nested OPNsense POST payloads as valid JSON', () {
    final body = OpnSenseApiClient.encodePostBody({
      'rule': {
        'action': 'pass',
        'interface': 'lan',
        'destination_port': '',
      },
    });

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    expect((decoded['rule'] as Map)['action'], 'pass');
    expect((decoded['rule'] as Map)['interface'], 'lan');
    expect((decoded['rule'] as Map)['destination_port'], '');
  });

  test('decodes JSON response exposed as text', () {
    final decoded = OpnSenseApiClient.normalizeResponseData(
      '{"result":"ok","uuid":"job-123"}',
    );
    expect(decoded, isA<Map>());
    expect((decoded as Map)['result'], 'ok');
    expect(decoded['uuid'], 'job-123');
  });

  test('leaves ordinary text response untouched', () {
    expect(OpnSenseApiClient.normalizeResponseData('plain output'), 'plain output');
  });
}
