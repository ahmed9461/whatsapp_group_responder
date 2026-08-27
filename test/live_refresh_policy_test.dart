import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_responder_app/core/live_refresh_policy.dart';

void main() {
  test('small SSE events refresh only their authoritative resources', () {
    expect(
      resourcesForProjectEvent('command.updated'),
      {LiveResource.commands},
    );
    expect(
      resourcesForProjectEvent('approval.decided'),
      {LiveResource.approvals, LiveResource.groups},
    );
    expect(
      resourcesForProjectEvent('outbound.target_sent'),
      {LiveResource.broadcasts},
    );
    expect(resourcesForProjectEvent('ready'), isEmpty);
  });

  test('authorization and settings events force status reconciliation', () {
    expect(
      resourcesForProjectEvent('device.updated'),
      contains(LiveResource.status),
    );
    expect(
      resourcesForProjectEvent('settings.updated'),
      {LiveResource.status, LiveResource.settings},
    );
    expect(
      resourcesForProjectEvent('auth_expired'),
      {LiveResource.status},
    );
  });
}
