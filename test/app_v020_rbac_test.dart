import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_responder_app/core/app_controller.dart';

void main() {
  test('device permissions and selected group scope come from server status', () {
    final controller = AppController();
    controller.status = {
      'device': {
        'role': 'replies',
        'roleLabel': '✏️ محرر الردود',
        'permissions': [
          'status.read',
          'events.read',
          'commands.read',
          'commands.write',
          'groups.read',
        ],
        'groupScopeMode': 'selected',
        'groupIds': [2, 9],
      },
    };

    expect(controller.deviceRole, 'replies');
    expect(controller.deviceRoleLabel, '✏️ محرر الردود');
    expect(controller.can('commands.write'), isTrue);
    expect(controller.can('settings.read'), isFalse);
    expect(controller.deviceGroupScopeMode, 'selected');
    expect(controller.deviceGroupIds, [2, 9]);
  });

  test('normal enrollment UI has no editable API address or embedded bot secret', () {
    final source = File('lib/features/enrollment/enrollment_page.dart')
        .readAsStringSync();
    expect(source, isNot(contains("labelText: 'عنوان API'")));
    expect(source, isNot(contains('BOT_TOKEN=')));
    expect(source, isNot(contains('api.telegram.org/bot')));
    expect(source, contains('طلب الربط عبر Telegram'));
  });

  test('navigation is built from server permissions', () {
    final source = File('lib/features/shell/home_shell.dart').readAsStringSync();
    expect(source, contains("can('commands.read')"));
    expect(source, contains("can('commands.write')"));
    expect(source, contains("can('scheduled.write')"));
    expect(source, contains("can('broadcasts.write')"));
  });
}
