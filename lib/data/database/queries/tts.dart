part of '../app_database.dart';

extension AppDatabaseTtsQueries on AppDatabase {
  // --- Job CRUD ---

  Future<List<TtsJob>> getRecentJobs({int limit = 50}) =>
      (select(ttsJobs)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .get();

  Stream<List<TtsJob>> watchRecentJobs({int limit = 50}) =>
      (select(ttsJobs)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .watch();

  Future<int> insertJob(TtsJobsCompanion job) => into(ttsJobs).insert(job);

  Future<bool> updateJob(TtsJob job) => update(ttsJobs).replace(job);

  // --- Quick TTS History ---

  Stream<List<QuickTtsHistory>> watchQuickTtsHistory({int limit = 100}) =>
      (select(quickTtsHistories)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .watch();

  Future<int> insertQuickTtsHistory(QuickTtsHistoriesCompanion entry) =>
      into(quickTtsHistories).insert(entry);

  Future<int> deleteQuickTtsHistory(String id) =>
      (delete(quickTtsHistories)..where((t) => t.id.equals(id))).go();

  Future<int> clearQuickTtsHistory() => delete(quickTtsHistories).go();

  Future<int> clearQuickTtsHistoryForAsset(String assetId) => (delete(
    quickTtsHistories,
  )..where((t) => t.voiceAssetId.equals(assetId))).go();

  Future<void> updateQuickTtsHistoryDuration(String id, double duration) =>
      (update(quickTtsHistories)..where((t) => t.id.equals(id))).write(
        QuickTtsHistoriesCompanion(audioDuration: Value(duration)),
      );
}
