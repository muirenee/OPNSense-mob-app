import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/firewall/aliases/alias_repository.dart';

void main() {
  test('parses firewall aliases', () {
    final aliases = AliasRepository.parse({
      'rows': [
        {
          'uuid': 'alias-1',
          'name': 'SERVERS',
          'type': 'host',
          'content': ['10.0.0.10', '10.0.0.11'],
          'description': 'Server hosts',
          'enabled': '1',
        },
      ],
    });

    expect(aliases, hasLength(1));
    expect(aliases.first.name, 'SERVERS');
    expect(aliases.first.content, contains('10.0.0.10'));
    expect(aliases.first.enabled, isTrue);
  });
}
