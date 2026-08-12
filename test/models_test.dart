import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_responder_app/core/models.dart';

void main() {
  test('ApiCommand parses structured content and safe targeting', () {
    final command = ApiCommand.fromJson({
      'id': 12,
      'title': 'السداد',
      'enabled': true,
      'responseText': 'موعد السداد',
      'responseContent': {
        'version': 1,
        'components': [
          {'type': 'text', 'text': 'موعد السداد'},
          {
            'type': 'image',
            'assetId': 9,
            'caption': 'التفاصيل',
            'asset': {
              'id': 9,
              'kind': 'image',
              'mimeType': 'image/jpeg',
              'sizeBytes': 100,
              'createdAt': 1,
            },
          },
        ],
      },
      'cooldownSeconds': 3,
      'usageCount': 5,
      'triggers': [
        {'id': 1, 'text': 'السداد', 'primary': true},
      ],
      'scopes': ['123@g.us'],
      'scopeMode': 'selected',
      'groupIds': [4],
    });
    expect(command.id, 12);
    expect(command.responseContent.components.length, 2);
    expect(command.responseContent.components.last.assetId, 9);
    expect(command.scopeMode, 'selected');
    expect(command.groupIds, [4]);
  });

  test('scheduled campaign parses messages and targets', () {
    final campaign = ApiScheduledCampaign.fromJson({
      'id': 2,
      'name': 'تذكيرات',
      'enabled': true,
      'intervalSeconds': 43200,
      'selectionMode': 'shuffle',
      'targetMode': 'selected',
      'messages': [
        {
          'id': 8,
          'text': 'مرحبا',
          'content': {
            'components': [
              {'type': 'text', 'text': 'مرحبا'},
            ],
          },
          'sortOrder': 0,
          'timesSent': 1,
        },
      ],
      'targets': [
        {'groupId': 3, 'groupName': 'تجربة', 'status': 'approved'},
      ],
    });
    expect(campaign.intervalSeconds, 43200);
    expect(campaign.groupIds, [3]);
    expect(campaign.messages.single.content.summary, 'مرحبا');
  });

  test('broadcast report parses per-group status', () {
    final broadcast = ApiBroadcast.fromJson({
      'id': 7,
      'kind': 'manual',
      'messageText': 'اختبار',
      'content': {
        'components': [
          {'type': 'text', 'text': 'اختبار'},
        ],
      },
      'targetMode': 'all',
      'status': 'completed',
      'targetCount': 2,
      'sentCount': 2,
      'failedCount': 0,
      'targets': [
        {'groupId': 1, 'groupName': 'أ', 'status': 'sent', 'attemptCount': 1},
      ],
    });
    expect(broadcast.status, 'completed');
    expect(broadcast.targets.single.groupName, 'أ');
  });

  test('statistics parse interactive range buckets and leaders', () {
    final statistics = ApiStatistics.fromJson({
      'period': '7d',
      'total': 14,
      'averagePerBucket': 2.0,
      'activeGroups': 3,
      'approvedGroups': 5,
      'commands': 4,
      'since': 100,
      'generatedAt': 200,
      'top': [
        {'id': 1, 'title': 'كفو', 'uses': 7},
      ],
      'topGroups': [
        {'id': 2, 'name': 'تجربة', 'uses': 8},
      ],
      'buckets': [
        {'startAt': 100, 'endAt': 150, 'uses': 5},
        {'startAt': 150, 'endAt': 200, 'uses': 9},
      ],
    });
    expect(statistics.period, '7d');
    expect(statistics.periodLabel, '7 أيام');
    expect(statistics.total, 14);
    expect(statistics.activeGroups, 3);
    expect(statistics.top.single.title, 'كفو');
    expect(statistics.topGroups.single.name, 'تجربة');
    expect(statistics.buckets.last.uses, 9);
  });

  test('EnrollmentResult keeps the enrollment token', () {
    final result = EnrollmentResult.fromJson({
      'id': 'enr_test',
      'enrollmentToken': 'wgr_enr_secret',
      'verificationCode': '123456',
      'status': 'pending',
      'expiresAt': 1000,
    });
    expect(result.enrollmentToken, 'wgr_enr_secret');
  });

  test('WhatsApp ready runtime state is connected even during credential lag', () {
    final status = ApiWhatsAppStatus.fromJson({
      'state': 'ready',
      'registered': false,
      'usableSession': false,
      'requiresRelink': false,
      'pairingReady': false,
    });
    expect(status.connected, isTrue);
  });
}
