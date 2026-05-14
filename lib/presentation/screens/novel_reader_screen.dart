import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/storage/novel_dialogue_rules_service.dart';
import 'package:neiroha/data/storage/novel_import_service.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/export_progress.dart';
import 'package:neiroha/presentation/widgets/project_card_grid.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

part '../widgets/novel_reader/editor.dart';
part '../widgets/novel_reader/playback.dart';
part '../widgets/novel_reader/chapters.dart';
part '../widgets/novel_reader/reader_pane.dart';
part '../widgets/novel_reader/controls.dart';
part '../widgets/novel_reader/settings_panel.dart';
part '../widgets/novel_reader/project_shell.dart';

/// Lightweight novel reader: import text chapters, read them comfortably, and
/// cache generated TTS locally per novel project.
class NovelReaderScreen extends ConsumerStatefulWidget {
  const NovelReaderScreen({super.key});

  @override
  ConsumerState<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends ConsumerState<NovelReaderScreen> {
  String? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    if (_selectedProjectId == null) return _buildProjectListScreen();
    return _NovelReaderEditor(
      key: ValueKey(_selectedProjectId),
      projectId: _selectedProjectId!,
      onClose: () => setState(() => _selectedProjectId = null),
    );
  }

  Widget _buildProjectListScreen() {
    final projectsAsync = ref.watch(novelProjectsStreamProvider);
    return Column(
      children: [
        _NovelProjectHeader(onCreate: _createProject),
        const Divider(height: 1),
        Expanded(
          child: projectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (projects) => ProjectCardGrid(
              emptyLabel: 'No novel projects yet',
              projects: [
                for (final p in projects)
                  ProjectCardData(
                    id: p.id,
                    name: p.name,
                    updatedAt: p.updatedAt,
                    icon: Icons.menu_book_rounded,
                    subtitle: _readerPreview(p),
                  ),
              ],
              onOpen: (id) => setState(() => _selectedProjectId = id),
              onDelete: (id) {
                ref.read(databaseProvider).deleteNovelProject(id);
              },
            ),
          ),
        ),
      ],
    );
  }

  String? _readerPreview(db.NovelProject project) {
    final voice = project.narratorVoiceAssetId == null ? 'No narrator' : null;
    if (voice != null) return voice;
    return 'Reading position ${project.currentGlobalIndex + 1}';
  }

  Future<void> _createProject() async {
    final banks = ref.read(voiceBanksStreamProvider).valueOrNull ?? const [];
    if (banks.isEmpty) {
      _snack('Create a Voice Bank first.');
      return;
    }
    final result = await showDialog<_CreateNovelResult>(
      context: context,
      builder: (_) => _CreateNovelDialog(banks: banks),
    );
    if (result == null) return;

    final dbx = ref.read(databaseProvider);
    final members = await dbx.getBankMembers(result.bankId);
    final narratorId = members.isNotEmpty ? members.first.voiceAssetId : null;
    final dialogueId = members.length > 1
        ? members[1].voiceAssetId
        : narratorId;
    final id = const Uuid().v4();
    final now = DateTime.now();
    await dbx.insertNovelProject(
      db.NovelProjectsCompanion(
        id: Value(id),
        name: Value(result.name),
        bankId: Value(result.bankId),
        narratorVoiceAssetId: Value(narratorId),
        dialogueVoiceAssetId: Value(dialogueId),
        readerTheme: const Value('dark'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    if (mounted) setState(() => _selectedProjectId = id);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
