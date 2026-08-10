import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_responder_app/core/models.dart';

void main() {
  test('ApiCommand parses the project v1 DTO', () {
    final command = ApiCommand.fromJson({
      'id': 12,
      'title': 'السداد',
      'enabled': true,
      'responseText': 'موعد السداد',
      'cooldownSeconds': 3,
      'usageCount': 5,
      'triggers': [
        {'id': 1, 'text': 'السداد', 'primary': true},
      ],
      'scopes': ['global'],
    });
    expect(command.id, 12);
    expect(command.title, 'السداد');
    expect(command.enabled, isTrue);
    expect(command.triggers.single.primary, isTrue);
    expect(command.scopes, ['global']);
  });

  test('EnrollmentResult keeps the enrollment token', () {
    final result = EnrollmentResult.fromJson({
      'id': 'enr_test',
      'enrollmentToken': 'wgr_enr_secret',
      'verificationCode': '123456',
      'status': 'pending',
      'expiresAt': 1000,
    });
    expect(result.id, 'enr_test');
    expect(result.enrollmentToken, 'wgr_enr_secret');
    expect(result.verificationCode, '123456');
  });

  test('statistics use the server uses field for top commands', () {
    final stats = ApiStatistics.fromJson({
      'total': 9,
      'approvedGroups': 2,
      'commands': 3,
      'top': [
        {'id': 7, 'title': 'السداد', 'uses': 6},
        {'id': 9, 'title': 'التسجيل', 'uses': 3},
      ],
    });

    expect(stats.total, 9);
    expect(stats.top.length, 2);
    expect(stats.top.first.title, 'السداد');
    expect(stats.top.first.uses, 6);
  });

  test('WhatsApp ready state is treated as connected', () {
    final status = ApiWhatsAppStatus.fromJson({
      'state': 'ready',
      'registered': true,
      'usableSession': true,
      'requiresRelink': false,
      'pairingReady': false,
    });

    expect(status.connected, isTrue);
    expect(status.requiresRelink, isFalse);
  });

  test('revoked WhatsApp state is not connected', () {
    final status = ApiWhatsAppStatus.fromJson({
      'state': 'revoked',
      'registered': false,
      'usableSession': false,
      'requiresRelink': true,
      'pairingReady': false,
    });

    expect(status.connected, isFalse);
    expect(status.requiresRelink, isTrue);
  });
}
