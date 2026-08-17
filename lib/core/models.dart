class ApiMediaAsset {
  const ApiMediaAsset({
    required this.id,
    required this.kind,
    required this.mimeType,
    required this.sizeBytes,
    required this.originalName,
    required this.createdAt,
  });

  final int id;
  final String kind;
  final String mimeType;
  final int sizeBytes;
  final String? originalName;
  final int createdAt;

  factory ApiMediaAsset.fromJson(Map<String, dynamic> json) => ApiMediaAsset(
        id: _int(json['id']),
        kind: '${json['kind'] ?? ''}',
        mimeType: '${json['mimeType'] ?? ''}',
        sizeBytes: _int(json['sizeBytes']),
        originalName: json['originalName']?.toString(),
        createdAt: _int(json['createdAt']),
      );
}

class ApiContentComponent {
  const ApiContentComponent({
    required this.type,
    this.text,
    this.assetId,
    this.caption,
    this.asset,
  });

  final String type;
  final String? text;
  final int? assetId;
  final String? caption;
  final ApiMediaAsset? asset;

  bool get isText => type == 'text';

  factory ApiContentComponent.fromJson(Map<String, dynamic> json) =>
      ApiContentComponent(
        type: '${json['type'] ?? ''}',
        text: json['text']?.toString(),
        assetId: json['assetId'] == null ? null : _int(json['assetId']),
        caption: json['caption']?.toString(),
        asset: json['asset'] is Map
            ? ApiMediaAsset.fromJson(
                Map<String, dynamic>.from(json['asset'] as Map),
              )
            : null,
      );

  Map<String, dynamic> toJson() => type == 'text'
      ? {'type': 'text', 'text': text ?? ''}
      : {
          'type': type,
          'assetId': assetId,
          if (caption != null && caption!.trim().isNotEmpty) 'caption': caption,
        };

  ApiContentComponent copyWith({String? caption}) => ApiContentComponent(
        type: type,
        text: text,
        assetId: assetId,
        caption: caption ?? this.caption,
        asset: asset,
      );
}

class ApiMessageContent {
  const ApiMessageContent({required this.components});
  final List<ApiContentComponent> components;

  bool get isEmpty => components.isEmpty;
  bool get isNotEmpty => components.isNotEmpty;

  factory ApiMessageContent.fromJson(Map<String, dynamic>? json) =>
      ApiMessageContent(
        components: json == null
            ? []
            : ((json['components'] as List?) ?? const [])
                .whereType<Map>()
                .map(
                  (item) => ApiContentComponent.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(),
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'components': components.map((item) => item.toJson()).toList(),
      };

  String get summary {
    if (components.isEmpty) return 'لا يوجد محتوى';
    return components.map((item) {
      return switch (item.type) {
        'text' => item.text ?? '',
        'image' => item.caption?.trim().isNotEmpty == true
            ? '🖼️ صورة — ${item.caption}'
            : '🖼️ صورة',
        'video' => item.caption?.trim().isNotEmpty == true
            ? '🎬 فيديو — ${item.caption}'
            : '🎬 فيديو',
        'voice' => item.caption?.trim().isNotEmpty == true
            ? '🎙️ رسالة صوتية — ${item.caption}'
            : '🎙️ رسالة صوتية',
        'audio' => item.caption?.trim().isNotEmpty == true
            ? '🎵 صوت — ${item.caption}'
            : '🎵 صوت',
        'file' => item.caption?.trim().isNotEmpty == true
            ? '📎 ملف — ${item.caption}'
            : '📎 ملف',
        _ => item.type,
      };
    }).join('\n');
  }
}

class ApiCommand {
  ApiCommand({
    required this.id,
    required this.title,
    required this.enabled,
    required this.responseText,
    required this.responseContent,
    required this.cooldownSeconds,
    required this.usageCount,
    required this.triggers,
    required this.scopes,
    required this.scopeMode,
    required this.groupIds,
  });

  final int id;
  final String title;
  final bool enabled;
  final String responseText;
  final ApiMessageContent responseContent;
  final int cooldownSeconds;
  final int usageCount;
  final List<ApiTrigger> triggers;
  final List<String> scopes;
  final String scopeMode;
  final List<int> groupIds;

  factory ApiCommand.fromJson(Map<String, dynamic> json) {
    final content = ApiMessageContent.fromJson(
      json['responseContent'] is Map
          ? Map<String, dynamic>.from(json['responseContent'] as Map)
          : null,
    );
    final legacy = '${json['responseText'] ?? ''}';
    return ApiCommand(
      id: _int(json['id']),
      title: '${json['title'] ?? ''}',
      enabled: json['enabled'] == true,
      responseText: legacy,
      responseContent: content.isNotEmpty
          ? content
          : ApiMessageContent(
              components: legacy.trim().isEmpty
                  ? []
                  : [ApiContentComponent(type: 'text', text: legacy)],
            ),
      cooldownSeconds: _int(json['cooldownSeconds']),
      usageCount: _int(json['usageCount']),
      triggers: ((json['triggers'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => ApiTrigger.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      scopes: ((json['scopes'] as List?) ?? const [])
          .map((item) => '$item')
          .toList(),
      scopeMode:
          '${json['scopeMode'] ?? (((json['scopes'] as List?)?.contains('global') == true) ? 'all' : 'selected')}',
      groupIds: ((json['groupIds'] as List?) ?? const []).map(_int).toList(),
    );
  }
}

class ApiTrigger {
  ApiTrigger({required this.id, required this.text, required this.primary});
  final int id;
  final String text;
  final bool primary;

  factory ApiTrigger.fromJson(Map<String, dynamic> json) => ApiTrigger(
        id: _int(json['id']),
        text: '${json['text'] ?? ''}',
        primary: json['primary'] == true,
      );
}

class ApiGroup {
  ApiGroup({
    required this.id,
    required this.name,
    required this.status,
    required this.responsesEnabled,
    required this.memberCount,
  });

  final int id;
  final String name;
  final String status;
  final bool responsesEnabled;
  final int? memberCount;
  bool get approved => status == 'approved';

  factory ApiGroup.fromJson(Map<String, dynamic> json) => ApiGroup(
        id: _int(json['id']),
        name: '${json['name'] ?? 'مجموعة بدون اسم'}',
        status: '${json['status'] ?? ''}',
        responsesEnabled: json['responsesEnabled'] == true,
        memberCount:
            json['memberCount'] == null ? null : _int(json['memberCount']),
      );
}

class ApiScheduledMessage {
  const ApiScheduledMessage({
    required this.id,
    required this.text,
    required this.content,
    required this.sortOrder,
    required this.timesSent,
    required this.lastSentAt,
  });

  final int id;
  final String text;
  final ApiMessageContent content;
  final int sortOrder;
  final int timesSent;
  final int? lastSentAt;

  factory ApiScheduledMessage.fromJson(Map<String, dynamic> json) =>
      ApiScheduledMessage(
        id: _int(json['id']),
        text: '${json['text'] ?? ''}',
        content: ApiMessageContent.fromJson(
          json['content'] is Map
              ? Map<String, dynamic>.from(json['content'] as Map)
              : null,
        ),
        sortOrder: _int(json['sortOrder']),
        timesSent: _int(json['timesSent']),
        lastSentAt:
            json['lastSentAt'] == null ? null : _int(json['lastSentAt']),
      );
}

class ApiScheduledTarget {
  const ApiScheduledTarget({
    required this.groupId,
    required this.groupName,
    required this.status,
  });

  final int groupId;
  final String groupName;
  final String status;

  factory ApiScheduledTarget.fromJson(Map<String, dynamic> json) =>
      ApiScheduledTarget(
        groupId: _int(json['groupId']),
        groupName: '${json['groupName'] ?? 'مجموعة'}',
        status: '${json['status'] ?? ''}',
      );
}

class ApiScheduledCampaign {
  const ApiScheduledCampaign({
    required this.id,
    required this.name,
    required this.enabled,
    required this.intervalSeconds,
    required this.selectionMode,
    required this.targetMode,
    required this.lastSentAt,
    required this.nextRunAt,
    required this.messages,
    required this.targets,
  });

  final int id;
  final String name;
  final bool enabled;
  final int intervalSeconds;
  final String selectionMode;
  final String targetMode;
  final int? lastSentAt;
  final int? nextRunAt;
  final List<ApiScheduledMessage> messages;
  final List<ApiScheduledTarget> targets;
  List<int> get groupIds => targets.map((item) => item.groupId).toList();

  factory ApiScheduledCampaign.fromJson(Map<String, dynamic> json) =>
      ApiScheduledCampaign(
        id: _int(json['id']),
        name: '${json['name'] ?? ''}',
        enabled: json['enabled'] == true,
        intervalSeconds: _int(json['intervalSeconds']),
        selectionMode: '${json['selectionMode'] ?? 'shuffle'}',
        targetMode: '${json['targetMode'] ?? 'all'}',
        lastSentAt:
            json['lastSentAt'] == null ? null : _int(json['lastSentAt']),
        nextRunAt: json['nextRunAt'] == null ? null : _int(json['nextRunAt']),
        messages: ((json['messages'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (item) => ApiScheduledMessage.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(),
        targets: ((json['targets'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (item) => ApiScheduledTarget.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(),
      );
}

class ApiOutboundTarget {
  const ApiOutboundTarget({
    required this.groupId,
    required this.groupName,
    required this.status,
    required this.attemptCount,
    required this.lastError,
    required this.sentAt,
  });

  final int groupId;
  final String groupName;
  final String status;
  final int attemptCount;
  final String? lastError;
  final int? sentAt;

  factory ApiOutboundTarget.fromJson(Map<String, dynamic> json) =>
      ApiOutboundTarget(
        groupId: _int(json['groupId']),
        groupName: '${json['groupName'] ?? 'مجموعة'}',
        status: '${json['status'] ?? ''}',
        attemptCount: _int(json['attemptCount']),
        lastError: json['lastError']?.toString(),
        sentAt: json['sentAt'] == null ? null : _int(json['sentAt']),
      );
}

class ApiBroadcast {
  const ApiBroadcast({
    required this.id,
    required this.kind,
    required this.messageText,
    required this.content,
    required this.targetMode,
    required this.status,
    required this.targetCount,
    required this.sentCount,
    required this.failedCount,
    required this.createdAt,
    required this.startedAt,
    required this.finishedAt,
    required this.targets,
  });

  final int id;
  final String kind;
  final String messageText;
  final ApiMessageContent content;
  final String targetMode;
  final String status;
  final int targetCount;
  final int sentCount;
  final int failedCount;
  final int? createdAt;
  final int? startedAt;
  final int? finishedAt;
  final List<ApiOutboundTarget> targets;
  bool get retryable => failedCount > 0;
  bool get cancellable => status == 'queued' || status == 'running';

  factory ApiBroadcast.fromJson(Map<String, dynamic> json) => ApiBroadcast(
        id: _int(json['id']),
        kind: '${json['kind'] ?? ''}',
        messageText: '${json['messageText'] ?? ''}',
        content: ApiMessageContent.fromJson(
          json['content'] is Map
              ? Map<String, dynamic>.from(json['content'] as Map)
              : null,
        ),
        targetMode: '${json['targetMode'] ?? 'all'}',
        status: '${json['status'] ?? ''}',
        targetCount: _int(json['targetCount']),
        sentCount: _int(json['sentCount']),
        failedCount: _int(json['failedCount']),
        createdAt: json['createdAt'] == null ? null : _int(json['createdAt']),
        startedAt: json['startedAt'] == null ? null : _int(json['startedAt']),
        finishedAt:
            json['finishedAt'] == null ? null : _int(json['finishedAt']),
        targets: ((json['targets'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (item) => ApiOutboundTarget.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(),
      );
}

class ApiApproval {
  ApiApproval({
    required this.id,
    required this.groupName,
    required this.memberCount,
    required this.actorName,
    required this.actorPhone,
    required this.expiresAt,
  });

  final int id;
  final String groupName;
  final int? memberCount;
  final String? actorName;
  final String? actorPhone;
  final int expiresAt;

  factory ApiApproval.fromJson(Map<String, dynamic> json) => ApiApproval(
        id: _int(json['id']),
        groupName: '${json['groupName'] ?? 'مجموعة'}',
        memberCount:
            json['memberCount'] == null ? null : _int(json['memberCount']),
        actorName: json['actorName']?.toString(),
        actorPhone: json['actorPhone']?.toString(),
        expiresAt: _int(json['expiresAt']),
      );
}

class ApiUsageRank {
  const ApiUsageRank({required this.id, required this.title, required this.uses});
  final int id;
  final String title;
  final int uses;

  factory ApiUsageRank.fromJson(Map<String, dynamic> json) => ApiUsageRank(
        id: _int(json['id']),
        title: '${json['title'] ?? ''}',
        uses: _int(json['uses']),
      );
}

class ApiGroupUsageRank {
  const ApiGroupUsageRank({required this.id, required this.name, required this.uses});
  final int id;
  final String name;
  final int uses;

  factory ApiGroupUsageRank.fromJson(Map<String, dynamic> json) =>
      ApiGroupUsageRank(
        id: _int(json['id']),
        name: '${json['name'] ?? 'مجموعة'}',
        uses: _int(json['uses']),
      );
}

class ApiUsageBucket {
  const ApiUsageBucket({
    required this.startAt,
    required this.endAt,
    required this.uses,
  });

  final int startAt;
  final int endAt;
  final int uses;

  factory ApiUsageBucket.fromJson(Map<String, dynamic> json) => ApiUsageBucket(
        startAt: _int(json['startAt']),
        endAt: _int(json['endAt']),
        uses: _int(json['uses']),
      );
}

class ApiStatistics {
  const ApiStatistics({
    required this.period,
    required this.total,
    required this.averagePerBucket,
    required this.activeGroups,
    required this.top,
    required this.topGroups,
    required this.buckets,
    required this.approvedGroups,
    required this.commands,
    required this.since,
    required this.generatedAt,
  });

  final String period;
  final int total;
  final double averagePerBucket;
  final int activeGroups;
  final List<ApiUsageRank> top;
  final List<ApiGroupUsageRank> topGroups;
  final List<ApiUsageBucket> buckets;
  final int approvedGroups;
  final int commands;
  final int since;
  final int generatedAt;

  String get periodLabel => switch (period) {
        '7d' => '7 أيام',
        '30d' => '30 يومًا',
        _ => '24 ساعة',
      };

  factory ApiStatistics.fromJson(Map<String, dynamic> json) => ApiStatistics(
        period: '${json['period'] ?? '24h'}',
        total: _int(json['total']),
        averagePerBucket: _double(json['averagePerBucket']),
        activeGroups: _int(json['activeGroups']),
        top: ((json['top'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (item) => ApiUsageRank.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
        topGroups: ((json['topGroups'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (item) => ApiGroupUsageRank.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(),
        buckets: ((json['buckets'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (item) => ApiUsageBucket.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(),
        approvedGroups: _int(json['approvedGroups']),
        commands: _int(json['commands']),
        since: _int(json['since']),
        generatedAt: _int(json['generatedAt']),
      );

  static const empty = ApiStatistics(
    period: '24h',
    total: 0,
    averagePerBucket: 0,
    activeGroups: 0,
    top: [],
    topGroups: [],
    buckets: [],
    approvedGroups: 0,
    commands: 0,
    since: 0,
    generatedAt: 0,
  );
}

class ApiWhatsAppStatus {
  const ApiWhatsAppStatus({
    required this.state,
    required this.registered,
    required this.usableSession,
    required this.requiresRelink,
    required this.pairingReady,
    required this.lastError,
  });

  final String state;
  final bool registered;
  final bool usableSession;
  final bool requiresRelink;
  final bool pairingReady;
  final String? lastError;

  // `ready` is the runtime connection truth. Credential persistence can lag a
  // freshly opened socket for a moment, so it must not make the UI contradict
  // itself by showing ready + disconnected simultaneously.
  bool get connected => state == 'ready';
  bool get connecting => state == 'connecting' || state == 'disconnected';

  factory ApiWhatsAppStatus.fromJson(Map<String, dynamic> json) =>
      ApiWhatsAppStatus(
        state: '${json['state'] ?? ''}',
        registered: json['registered'] == true,
        usableSession: json['usableSession'] == true,
        requiresRelink: json['requiresRelink'] == true,
        pairingReady: json['pairingReady'] == true,
        lastError: json['lastError']?.toString(),
      );

  static const empty = ApiWhatsAppStatus(
    state: '',
    registered: false,
    usableSession: false,
    requiresRelink: false,
    pairingReady: false,
    lastError: null,
  );
}

class EnrollmentResult {
  EnrollmentResult({
    required this.id,
    required this.enrollmentToken,
    required this.verificationCode,
    required this.status,
    required this.expiresAt,
  });

  final String id;
  final String enrollmentToken;
  final String verificationCode;
  final String status;
  final int expiresAt;

  factory EnrollmentResult.fromJson(Map<String, dynamic> json) => EnrollmentResult(
        id: '${json['id']}',
        enrollmentToken: '${json['enrollmentToken']}',
        verificationCode: '${json['verificationCode']}',
        status: '${json['status']}',
        expiresAt: _int(json['expiresAt']),
      );
}

class SessionTokens {
  SessionTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final int accessExpiresAt;
  final int refreshExpiresAt;

  factory SessionTokens.fromJson(Map<String, dynamic> json) => SessionTokens(
        accessToken: '${json['accessToken']}',
        refreshToken: '${json['refreshToken']}',
        accessExpiresAt: _int(json['accessExpiresAt']),
        refreshExpiresAt: _int(json['refreshExpiresAt']),
      );
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
