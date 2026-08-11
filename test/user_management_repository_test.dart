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

  test('parses firewall groups with human labels from option maps', () {
    final groups = UserManagementRepository.parseGroups({
      'rows': [
        {
          'uuid': 'g1',
          'name': 'portal-users',
          'description': 'Captive portal users',
          'member': {
            '1001': {'value': 'alice', 'selected': 1},
            '1002': {'value': 'bob', 'selected': 0},
          },
          'priv': {
            'page-system-usermanager': {
              'value': 'System: User Manager',
              'selected': 1,
            },
            'page-all': {'value': 'All pages', 'selected': 0},
          },
        },
      ],
    });

    expect(groups.single.name, 'portal-users');
    expect(groups.single.member, 'alice');
    expect(groups.single.member, isNot(contains('bob')));
    expect(groups.single.privileges, 'System: User Manager');
    expect(groups.single.privileges, isNot(contains('{')));
  });

  test('extracts selected user group memberships and privileges', () {
    final model = <String, dynamic>{
      'group_memberships': {
        '2000': {'value': 'Portal Users', 'selected': 1},
        '2001': {'value': 'Operators', 'selected': 0},
      },
      'priv': {
        'page-system-usermanager': {
          'value': 'System: User Manager',
          'selected': 1,
        },
      },
    };

    expect(
      UserManagementRepository.selectedChoices(model, 'group_memberships'),
      {'2000'},
    );
    expect(
      UserManagementRepository.selectedChoices(model, 'priv'),
      {'page-system-usermanager'},
    );
    expect(
      UserManagementRepository.encodeChoices({'2000', '2001'}),
      '2000,2001',
    );
  });
}
