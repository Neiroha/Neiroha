import 'dart:convert';

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_scene_state.dart';

class RoleAnalysisCheckpoint {
  RoleAnalysisCheckpoint({
    required this.signature,
    required this.providerId,
    required this.model,
    this.stage = 'planCast',
    this.skillName = '',
    this.skillVersion = '',
    this.skillDigest = '',
    this.nextSegment = 0,
    this.calls = 0,
    this.rosterReady = false,
    this.rosterConfirmed = false,
    this.sceneSummary = '',
    this.error,
    this.feedback = '',
    this.segmentationVersion = '',
    this.scene = const RoleSceneState(),
    this.reviewedSegments = 0,
    this.reviewChanges = 0,
  });
  final String signature;
  final String providerId;
  final String model;
  final String skillName;
  final String skillVersion;
  final String skillDigest;
  String stage;
  int nextSegment;
  int calls;
  bool rosterReady;
  bool rosterConfirmed;
  String sceneSummary;
  String? error;
  String feedback;
  final String segmentationVersion;
  RoleSceneState scene;
  int reviewedSegments;
  int reviewChanges;

  Map<String, Object?> toJson() => {
    'version': 1,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'signature': signature,
    'providerId': providerId,
    'model': model,
    'skillName': skillName,
    'skillVersion': skillVersion,
    'skillDigest': skillDigest,
    'stage': stage,
    'nextSegment': nextSegment,
    'calls': calls,
    'rosterReady': rosterReady,
    'rosterConfirmed': rosterConfirmed,
    'sceneSummary': sceneSummary,
    'error': error,
    'feedback': feedback,
    'segmentationVersion': segmentationVersion,
    'scene': scene.toJson(),
    'reviewedSegments': reviewedSegments,
    'reviewChanges': reviewChanges,
  };
  factory RoleAnalysisCheckpoint.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unknown analysis checkpoint version.');
    }
    return RoleAnalysisCheckpoint(
      signature: json['signature'] as String,
      providerId: json['providerId'] as String,
      model: json['model'] as String,
      skillName: json['skillName'] as String? ?? '',
      skillVersion: json['skillVersion'] as String? ?? '',
      skillDigest: json['skillDigest'] as String? ?? '',
      stage: json['stage'] as String,
      nextSegment: json['nextSegment'] as int,
      calls: json['calls'] as int,
      rosterReady: json['rosterReady'] as bool,
      rosterConfirmed: json['rosterConfirmed'] as bool,
      sceneSummary: json['sceneSummary'] as String,
      error: json['error'] as String?,
      feedback: json['feedback'] as String? ?? '',
      segmentationVersion: json['segmentationVersion'] as String? ?? '',
      scene: RoleSceneState.fromJson(
        (json['scene'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      reviewedSegments: json['reviewedSegments'] as int? ?? 0,
      reviewChanges: json['reviewChanges'] as int? ?? 0,
    );
  }
}

class RoleAnalysisCheckpointStore {
  const RoleAnalysisCheckpointStore(this.database);
  final db.AppDatabase database;
  String key(String projectId, String chapterId) =>
      'novel.roleAnalysis.$projectId.$chapterId';
  Future<RoleAnalysisCheckpoint?> load(
    String projectId,
    String chapterId,
  ) async {
    final value = await database.getSetting(key(projectId, chapterId));
    return value == null
        ? null
        : RoleAnalysisCheckpoint.fromJson(
            jsonDecode(value) as Map<String, dynamic>,
          );
  }

  Future<void> save(
    String projectId,
    String chapterId,
    RoleAnalysisCheckpoint checkpoint,
  ) => database.setSetting(
    key(projectId, chapterId),
    jsonEncode(checkpoint.toJson()),
  );
  Future<Map<String, dynamic>?> _previousCompleted(
    String projectId,
    String chapterId,
  ) async {
    final chapters = await database.getNovelChapters(projectId);
    final current = chapters.where((c) => c.id == chapterId).firstOrNull;
    if (current == null) return null;
    final previous =
        chapters.where((c) => c.orderIndex < current.orderIndex).toList()
          ..sort((a, b) => b.orderIndex.compareTo(a.orderIndex));
    for (final chapter in previous) {
      final value = await database.getSetting(key(projectId, chapter.id));
      if (value == null) continue;
      final object = jsonDecode(value) as Map<String, dynamic>;
      if (object['version'] == 1 && object['stage'] == 'completed') {
        return object;
      }
    }
    return null;
  }

  Future<String> recentScene(String projectId, String chapterId) async =>
      (await _previousCompleted(projectId, chapterId))?['sceneSummary']
          as String? ??
      '';

  Future<RoleSceneState> recentSceneState(
    String projectId,
    String chapterId,
  ) async {
    final previous = await _previousCompleted(projectId, chapterId);
    return RoleSceneState.fromJson(
      (previous?['scene'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  Stream<RoleAnalysisCheckpoint?> watch(String projectId, String chapterId) =>
      (database.select(database.appSettings)
            ..where((t) => t.key.equals(key(projectId, chapterId))))
          .watchSingleOrNull()
          .map(
            (row) => row == null
                ? null
                : RoleAnalysisCheckpoint.fromJson(
                    jsonDecode(row.value) as Map<String, dynamic>,
                  ),
          );
}
