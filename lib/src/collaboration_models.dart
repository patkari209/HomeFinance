import 'dart:convert';

enum SyncEntityType {
  expense,
  earning,
  savings,
  savingsAllocation,
  investment,
  asset,
  liability,
  forexTransfer,
  fxRate,
  settings,
}

enum SyncActionType { created, updated, deleted, imported, replaced }

enum PairSessionRole { host, guest }

enum PairConnectionState { disconnected, advertising, scanning, paired, syncing }

class SignedInProfile {
  SignedInProfile({
    required this.displayName,
    required this.email,
    required this.id,
    this.photoUrl,
  });

  final String displayName;
  final String email;
  final String id;
  final String? photoUrl;

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'email': email,
        'id': id,
        'photoUrl': photoUrl,
      };

  factory SignedInProfile.fromJson(Map<String, dynamic> json) {
    return SignedInProfile(
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      id: json['id'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
    );
  }
}

class PairSession {
  PairSession({
    required this.sessionCode,
    required this.role,
    required this.connectionState,
    required this.createdAt,
    this.localUser,
    this.remoteUser,
    this.lastSyncedAt,
  });

  final String sessionCode;
  final PairSessionRole role;
  final PairConnectionState connectionState;
  final DateTime createdAt;
  final SignedInProfile? localUser;
  final SignedInProfile? remoteUser;
  final DateTime? lastSyncedAt;

  PairSession copyWith({
    PairSessionRole? role,
    PairConnectionState? connectionState,
    SignedInProfile? localUser,
    SignedInProfile? remoteUser,
    DateTime? lastSyncedAt,
  }) {
    return PairSession(
      sessionCode: sessionCode,
      role: role ?? this.role,
      connectionState: connectionState ?? this.connectionState,
      createdAt: createdAt,
      localUser: localUser ?? this.localUser,
      remoteUser: remoteUser ?? this.remoteUser,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionCode': sessionCode,
        'role': role.name,
        'connectionState': connectionState.name,
        'createdAt': createdAt.toIso8601String(),
        'localUser': localUser?.toJson(),
        'remoteUser': remoteUser?.toJson(),
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      };

  factory PairSession.fromJson(Map<String, dynamic> json) {
    return PairSession(
      sessionCode: json['sessionCode'] as String? ?? '',
      role: PairSessionRole.values.byName(
        json['role'] as String? ?? PairSessionRole.host.name,
      ),
      connectionState: PairConnectionState.values.byName(
        json['connectionState'] as String? ?? PairConnectionState.disconnected.name,
      ),
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      localUser: json['localUser'] == null
          ? null
          : SignedInProfile.fromJson(json['localUser'] as Map<String, dynamic>),
      remoteUser: json['remoteUser'] == null
          ? null
          : SignedInProfile.fromJson(json['remoteUser'] as Map<String, dynamic>),
      lastSyncedAt: json['lastSyncedAt'] == null
          ? null
          : DateTime.parse(json['lastSyncedAt'] as String),
    );
  }
}

class FinanceSyncEvent {
  FinanceSyncEvent({
    required this.id,
    required this.entityType,
    required this.actionType,
    required this.recordId,
    required this.timestamp,
    required this.snapshot,
  });

  final String id;
  final SyncEntityType entityType;
  final SyncActionType actionType;
  final String recordId;
  final DateTime timestamp;
  final String snapshot;

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityType': entityType.name,
        'actionType': actionType.name,
        'recordId': recordId,
        'timestamp': timestamp.toIso8601String(),
        'snapshot': snapshot,
      };

  String encode() => jsonEncode(toJson());

  factory FinanceSyncEvent.fromJson(Map<String, dynamic> json) {
    return FinanceSyncEvent(
      id: json['id'] as String,
      entityType: SyncEntityType.values.byName(
        json['entityType'] as String? ?? SyncEntityType.settings.name,
      ),
      actionType: SyncActionType.values.byName(
        json['actionType'] as String? ?? SyncActionType.replaced.name,
      ),
      recordId: json['recordId'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      snapshot: json['snapshot'] as String? ?? '',
    );
  }
}
