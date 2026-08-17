import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_responder_app/core/approval_timeout.dart';
import 'package:whatsapp_responder_app/core/models.dart';

void main() {
  group('approval timeout parsing', () {
    test('accepts seconds, minutes, hours, Arabic labels, and Arabic digits', () {
      expect(parseApprovalTimeoutInput('45'), 45);
      expect(parseApprovalTimeoutInput('2m'), 120);
      expect(parseApprovalTimeoutInput('10 دقائق'), 600);
      expect(parseApprovalTimeoutInput('1h'), 3600);
      expect(parseApprovalTimeoutInput('30 ثانية'), 30);
      expect(parseApprovalTimeoutInput('١٠ دقائق'), 600);
      expect(parseApprovalTimeoutInput('۳۰ ثانية'), 30);
    });

    test('enforces the backend range of 5 seconds to 24 hours', () {
      expect(parseApprovalTimeoutInput('4'), isNull);
      expect(parseApprovalTimeoutInput('86400'), 86400);
      expect(parseApprovalTimeoutInput('25h'), isNull);
      expect(parseApprovalTimeoutInput('abc'), isNull);
    });

    test('formats common timeout values for the settings UI', () {
      expect(formatApprovalTimeout(30), '30 ثانية');
      expect(formatApprovalTimeout(60), 'دقيقة واحدة');
      expect(formatApprovalTimeout(300), '5 دقائق');
      expect(formatApprovalTimeout(3600), 'ساعة واحدة');
    });
  });

  test('document components serialize safely and have an Arabic summary', () {
    const content = ApiMessageContent(
      components: [
        ApiContentComponent(
          type: 'file',
          assetId: 77,
          caption: 'الخطة الدراسية',
        ),
      ],
    );

    expect(content.toJson(), {
      'version': 1,
      'components': [
        {
          'type': 'file',
          'assetId': 77,
          'caption': 'الخطة الدراسية',
        },
      ],
    });
    expect(content.summary, '📎 ملف — الخطة الدراسية');
  });
}
