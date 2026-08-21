import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('device permissions and group scope are read from server status', () {
    final source = File('lib/core/app_controller.dart').readAsStringSync();
    expect(source, contains("status['device']"));
    expect(source, contains("deviceAccess['permissions']"));
    expect(source, contains("bool can(String permission)"));
    expect(source, contains("deviceAccess['groupScopeMode']"));
    expect(source, contains("deviceAccess['groupIds']"));
    expect(source, contains("can('commands.read')"));
    expect(source, contains("can('settings.read')"));
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
