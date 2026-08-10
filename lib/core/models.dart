class ApiCommand {
  ApiCommand({
    required this.id,
    required this.title,
    required this.enabled,
    required this.responseText,
    required this.cooldownSeconds,
    required this.usageCount,
    required this.triggers,
    required this.scopes,
  });

  final int id;
  final String title;
  final bool enabled;
  final String responseText;
  final int cooldownSeconds;
  final int usageCount;
  final List<ApiTrigger> triggers;
  final List<String> scopes;

  factory ApiCommand.fromJson(Map<String, dynamic> json) {
    return ApiCommand(
      id: _int(json['id']),
      title: '${json['title'] ?? ''}',
      enabled: json['enabled'] == true,
      responseText: '${json['responseText'] ?? ''}',
      cooldownSeconds: _int(json['cooldownSeconds']),
      usageCount: _int(json['usageCount']),
      triggers: ((json['triggers'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ApiTrigger.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      scopes: ((json['scopes'] as List?) ?? const []).map((e) => '$e').toList(),
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

  factory ApiGroup.fromJson(Map<String, dynamic> json) => ApiGroup(
        id: _int(json['id']),
        name: '${json['name'] ?? 'مجموعة بدون اسم'}',
        status: '${json['status'] ?? ''}',
        responsesEnabled: json['responsesEnabled'] == true,
        memberCount: json['memberCount'] == null ? null : _int(json['memberCount']),
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
        memberCount: json['memberCount'] == null ? null : _int(json['memberCount']),
        actorName: json['actorName']?.toString(),
        actorPhone: json['actorPhone']?.toString(),
        expiresAt: _int(json['expiresAt']),
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

int _int(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
