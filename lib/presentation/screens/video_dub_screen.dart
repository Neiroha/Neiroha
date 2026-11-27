import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:neiroha/presentation/widgets/layout/page_header.dart';
import 'package:neiroha/presentation/widgets/project_creation_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/widgets/project_card_grid.dart';
import 'package:neiroha/presentation/widgets/project_settings_dialog.dart';
import 'package:neiroha/presentation/widgets/video_dub/editor.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:uuid/uuid.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_colors.dart';

/// Video Dub — dub video with TTS generated from subtitle cues.
///
/// List mode: grid of project cards (searchable, sorted by most recent edit).
/// Editor mode: video surface (media_kit), cue-synced timeline, subtitle
/// panel. Save returns to the list.
class VideoDubScreen extends ConsumerStatefulWidget {
  final bool active;

  const VideoDubScreen({super.key, this.active = true});

  @override
  ConsumerState<VideoDubScreen> createState() => _VideoDubScreenState();
}

class _VideoDubScreenState extends ConsumerState<VideoDubScreen> {
  String? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_isAndroidPhoneLayout(context, constraints)) {
          return _buildUnsupportedPhoneScreen();
        }
        if (_selectedProjectId == null) {
          return _buildProjectListScreen();
        }
        return VideoDubEditor(
          key: ValueKey(_selectedProjectId),
          projectId: _selectedProjectId!,
          active: widget.active,
          onClose: () => setState(() => _selectedProjectId = null),
        );
      },
    );
  }

  bool _isAndroidPhoneLayout(BuildContext context, BoxConstraints constraints) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final fallback = MediaQuery.sizeOf(context);
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : fallback.width;
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : fallback.height;
    final shortest = math.min(width, height);
    final longest = math.max(width, height);
    final aspectRatio = shortest <= 0 ? 1.0 : longest / shortest;
    return shortest < 600 && aspectRatio >= 1.75;
  }

  Widget _buildUnsupportedPhoneScreen() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        PageHeader(icon: Icons.movie_filter_rounded, title: l10n.navVideoDub),
        const Divider(height: 1),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tablet_mac_rounded,
                      size: 58,
                      color: context.fg.withValues(alpha: 0.18),
                    ),
                    SizedBox(height: 18),
                    Text(
                      l10n.uiVideoDubUnavailableOnAndroidPhone,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      l10n.uiVideoDubUnavailableOnAndroidPhoneDescription,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.fg.withValues(alpha: 0.55),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────── List mode ─────────────────

  Widget _buildProjectListScreen() {
    final projectsAsync = ref.watch(videoDubProjectsStreamProvider);
    final banks =
        ref.watch(voiceBanksStreamProvider).value ?? const <db.VoiceBank>[];
    return Column(
      children: [
        _buildListHeader(),
        const Divider(height: 1),
        Expanded(
          child: projectsAsync.when(
            loading: () => Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(AppLocalizations.of(context).uiError2(e))),
            data: (projects) => ProjectCardGrid(
              emptyLabel: AppLocalizations.of(context).uiNoVideoDubProjectsYet,
              projects: [
                for (final p in projects)
                  ProjectCardData(
                    id: p.id,
                    name: p.name,
                    updatedAt: p.updatedAt,
                    icon: Icons.movie_filter_rounded,
                    subtitle: p.videoPath == null
                        ? AppLocalizations.of(context).uiNoVideoLoaded
                        : _fileBaseName(p.videoPath!),
                  ),
              ],
              onOpen: (id) => setState(() => _selectedProjectId = id),
              onSettings: (card) => unawaited(
                _showProjectSettings(
                  projects.where((p) => p.id == card.id).firstOrNull,
                  banks,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader() {
    final l10n = AppLocalizations.of(context);
    return PageHeader(
      icon: Icons.movie_filter_rounded,
      title: l10n.navVideoDub,
      subtitle: l10n.uiDubVideoWithTTSFromSubtitleCues,
      actions: [
        FilledButton.icon(
          onPressed: _createProject,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(l10n.uiNewProject),
        ),
      ],
    );
  }

  Future<void> _showProjectSettings(
    db.VideoDubProject? project,
    List<db.VoiceBank> banks,
  ) async {
    if (project == null) return;
    final result = await showProjectSettingsDialog(
      context: context,
      projectName: project.name,
      bankId: project.bankId,
      banks: banks,
      autoNormalizeLoudness: project.autoNormalizeLoudness,
    );
    if (result == null) return;
    final database = ref.read(databaseProvider);
    if (result.deleteRequested) {
      await database.deleteVideoDubProject(project.id);
      return;
    }
    final bankChanged = result.bankId != project.bankId;
    if (result.name != project.name ||
        bankChanged ||
        result.autoNormalizeLoudness != project.autoNormalizeLoudness) {
      await database.updateVideoDubProject(
        project.copyWith(
          name: result.name,
          bankId: result.bankId,
          autoNormalizeLoudness: result.autoNormalizeLoudness,
          updatedAt: DateTime.now(),
        ),
      );
      if (bankChanged) {
        await _clearVideoDubProjectVoiceAssignments(project.id);
      }
    }
  }

  Future<void> _clearVideoDubProjectVoiceAssignments(String projectId) async {
    final database = ref.read(databaseProvider);
    final cues = await database.getSubtitleCues(projectId);
    for (final cue in cues) {
      await database.updateSubtitleCue(
        cue.copyWith(
          voiceAssetId: const Value(null),
          audioPath: const Value(null),
          audioDuration: const Value(null),
          error: const Value(null),
          missing: false,
        ),
      );
    }
  }

  Future<void> _createProject() async {
    final banks = ref.read(voiceBanksStreamProvider).value ?? [];
    if (banks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).uiCreateAVoiceBankFirst),
          ),
        );
      }
      return;
    }

    final result = await showProjectCreationDialog(
      context: context,
      title: AppLocalizations.of(context).uiNewVideoDubProject,
      banks: banks,
    );

    if (result != null && mounted) {
      final id = const Uuid().v4();
      final now = DateTime.now();
      await ref
          .read(databaseProvider)
          .insertVideoDubProject(
            db.VideoDubProjectsCompanion(
              id: Value(id),
              name: Value(result.name),
              bankId: Value(result.bankId),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      if (mounted) setState(() => _selectedProjectId = id);
    }
  }

  String _fileBaseName(String path) {
    final sep = path.contains('\\') ? '\\' : '/';
    final parts = path.split(sep);
    return parts.isEmpty ? path : parts.last;
  }
}
