import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/core/api/api_choice.dart';

void main() {
  test('parses OPNsense option map into labels and selected values', () {
    final choices = parseApiChoices({
      '1000': {'value': 'Admins', 'selected': 0},
      '2000': {'value': 'Portal Users', 'selected': 1},
    });

    expect(choices, hasLength(2));
    expect(
      choices.singleWhere((choice) => choice.value == '2000').label,
      'Portal Users',
    );
    expect(
      choices.singleWhere((choice) => choice.value == '2000').selected,
      isTrue,
    );
    expect(selectedApiChoiceValues({
      '1000': {'value': 'Admins', 'selected': 0},
      '2000': {'value': 'Portal Users', 'selected': 1},
    }), {'2000'});
  });

  test('displays selected human labels instead of JSON-like maps', () {
    final text = apiChoiceDisplayText({
      'wan': {'value': 'WAN', 'selected': 1},
      'lan': {'value': 'LAN', 'selected': 0},
    });
    expect(text, 'WAN');
    expect(text, isNot(contains('{')));
  });

  test('encodes multi selections as stable comma separated machine values', () {
    expect(
      encodeApiChoiceValues({'2000', '1000', '2000'}),
      '1000,2000',
    );
  });
}
