import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/users/user_management_repository.dart';

void main() {
  test('parses firewall users and protects system scope', () {
    final users = UserManagementRepository.parseUsers({
      'rows': [
        {
          'uuid': 'u1',
          'name': 'alice',
          'descr': 'Alice Example',
          'email': 'alice@example.test',
          'scope': 'user',
          'disabled': '0',
          'is_admin': false,
        },
        {
          'uuid': 'u2',
          'name': 'root',
          'scope': 'system',
          'disabled': '0',
          'is_admin': true,
        },
      ],
    });

    expect(users, hasLength(2));
    expect(users.first.name, 'alice');
    expect(users.last.isSystem, isTrue);
    expect(users.last.isAdmin, isTrue);
  });

  test('parses firewall groups', () {
    final groups = UserManagementRepository.parseGroups({
      'rows': [
        {
          'uuid': 'g1',
          'name': 'portal-users',
          'description': 'Captive portal users',
          'member': ['alice', 'bob'],
          'priv': ['page-system-usermanager'],
        },
      ],
    });

    expect(groups.single.name, 'portal-users');
    expect(groups.single.member, contains('alice'));
  });
}
