enum LiveResource {
  status,
  commands,
  groups,
  approvals,
  statistics,
  settings,
  whatsapp,
  scheduled,
  broadcasts,
}

Set<LiveResource> resourcesForProjectEvent(String eventType) {
  if (eventType == 'ready') return const {};
  if (eventType == 'auth_expired' || eventType == 'device_revoked') {
    return const {LiveResource.status};
  }
  if (eventType.startsWith('command.')) {
    return eventType == 'command.used'
        ? const {LiveResource.statistics}
        : const {LiveResource.commands};
  }
  if (eventType.startsWith('group.')) {
    return const {LiveResource.groups};
  }
  if (eventType.startsWith('approval.')) {
    return const {LiveResource.approvals, LiveResource.groups};
  }
  if (eventType.startsWith('settings.')) {
    return const {LiveResource.status, LiveResource.settings};
  }
  if (eventType.startsWith('scheduled.')) {
    return const {LiveResource.scheduled};
  }
  if (eventType.startsWith('outbound.')) {
    return const {LiveResource.broadcasts};
  }
  if (eventType.startsWith('device.')) {
    return const {LiveResource.status};
  }
  if (eventType.startsWith('whatsapp.')) {
    return const {LiveResource.status, LiveResource.whatsapp};
  }
  return const {};
}
