import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/services/synthesis/quick_tts_service.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/actions/voice_health_warning.dart';
import 'package:neiroha/presentation/widgets/dialog_tts/chat_list_view.dart';
import 'package:neiroha/presentation/widgets/dialog_tts/create_project_dialog.dart';
import 'package:neiroha/presentation/widgets/dialog_tts/dialog_mode_view.dart';
import 'package:neiroha/presentation/widgets/dialog_tts/editor_project_bar.dart';
import 'package:neiroha/presentation/widgets/dialog_tts/input_bar.dart';
import 'package:neiroha/presentation/widgets/dialog_tts/project_list_header.dart';
import 'package:neiroha/presentation/widgets/dialog_tts/settings_panel.dart';
import 'package:neiroha/presentation/widgets/loudness_normalize_dialog.dart';
import 'package:neiroha/presentation/widgets/persistent_audio_bar.dart';
import 'package:neiroha/presentation/widgets/project_card_grid.dart';
import 'package:neiroha/presentation/widgets/project_settings_dialog.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

part '../widgets/dialog_tts/dialog_editor.dart';

/// Dialog TTS — multi-character conversation with project management.
///
/// List mode: grid of project cards (matches Phase TTS / Video Dub).
/// Editor mode: top bar + split pane (left chat + input, right settings).
class DialogTtsScreen extends ConsumerStatefulWidget {
  const DialogTtsScreen({super.key});

  @override
  ConsumerState<DialogTtsScreen> createState() => _DialogTtsScreenState();
}

class _DialogTtsScreenState extends ConsumerState<DialogTtsScreen> {
  String? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    if (_selectedProjectId == null) {
      return _buildProjectListScreen();
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          AppBackIntent.markChildHandled();
          setState(() => _selectedProjectId = null);
        }
      },
      child: _DialogTtsEditor(
        key: ValueKey(_selectedProjectId),
        projectId: _selectedProjectId!,
        onClose: () => setState(() => _selectedProjectId = null),
      ),
    );
  }

  // ───────────────── List mode ─────────────────

  Widget _buildProjectListScreen() {
    final projectsAsync = ref.watch(dialogTtsProjectsStreamProvider);
    final banks =
        ref.watch(voiceBanksStreamProvider).value ?? const <db.VoiceBank>[];
    return Column(
      children: [
        ProjectListHeader(onCreate: _createProject),
        const Divider(height: 1),
        Expanded(
          child: projectsAsync.when(
            loading: () => Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(AppLocalizations.of(context).uiError2(e))),
            data: (projects) => ProjectCardGrid(
              emptyLabel: AppLocalizations.of(context).uiNoDialogProjectsYet,
              projects: [
                for (final p in projects)
                  ProjectCardData(
                    id: p.id,
                    name: p.name,
                    updatedAt: p.updatedAt,
                    icon: Icons.forum_rounded,
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

  Future<void> _showProjectSettings(
    db.DialogTtsProject? project,
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
      await database.deleteDialogTtsProject(project.id);
      return;
    }
    final bankChanged = result.bankId != project.bankId;
    if (result.name != project.name ||
        bankChanged ||
        result.autoNormalizeLoudness != project.autoNormalizeLoudness) {
      await database.updateDialogTtsProject(
        project.copyWith(
          name: result.name,
          bankId: result.bankId,
          autoNormalizeLoudness: result.autoNormalizeLoudness,
          updatedAt: DateTime.now(),
        ),
      );
      if (bankChanged) {
        await _clearDialogProjectVoiceAssignments(project.id);
      }
    }
  }

  Future<void> _clearDialogProjectVoiceAssignments(String projectId) async {
    final database = ref.read(databaseProvider);
    final lines = await database.getDialogTtsLines(projectId);
    for (final line in lines) {
      await database.updateDialogTtsLine(
        line.copyWith(
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
    final banks = ref.read(voiceBanksStreamProvider).value ?? const [];
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

    final result = await showCreateDialogTtsProjectDialog(
      context: context,
      banks: banks,
    );
    if (result == null) return;

    final id = const Uuid().v4();
    final now = DateTime.now();
    await ref
        .read(databaseProvider)
        .insertDialogTtsProject(
          db.DialogTtsProjectsCompanion(
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
