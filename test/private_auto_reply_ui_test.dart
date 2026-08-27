import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner settings expose private auto reply without widening device permissions', () {
    final settings = File('lib/features/settings/settings_page.dart').readAsStringSync();
    final api = File('lib/core/api/api_client.dart').readAsStringSync();
    final access = File('lib/features/more/more_page.dart').readAsStringSync();

    expect(settings, contains('الرد التلقائي للخاص'));
    expect(settings, contains('رسالة واحدة لكل شخص خلال 12 ساعة'));
    expect(settings, contains('_savePrivateAutoReplyMessage'));
    expect(api, contains("patchMap('/settings', {'privateAutoReply': fields})"));
    expect(access, contains("can('settings.read')"));
  });
}
