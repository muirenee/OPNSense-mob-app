import 'package:flutter_test/flutter_test.dart';
import 'package:netsource_opn_manager/features/services/services_repository.dart';

void main() {
  test('parses and sorts running services first', () {
    final services = ServicesRepository.parseServices({
      'rows': [
        {'name': 'stopped', 'status': 'stopped'},
        {'name': 'unbound', 'status': 'running'},
      ],
    });

    expect(services, hasLength(2));
    expect(services.first.name, 'unbound');
    expect(services.first.isRunning, isTrue);
  });
}
