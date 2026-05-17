import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/widgets/project_card_grid.dart';
import 'package:neiroha/presentation/widgets/video_dub/editor.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:uuid/uuid.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

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
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Row(
            children: [
              Icon(
                Icons.movie_filter_rounded,
                color: Colors.white.withValues(alpha: 0.42),
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.navVideoDub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
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
                      color: Colors.white.withValues(alpha: 0.18),
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
                        color: Colors.white.withValues(alpha: 0.55),
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
              onDelete: (id) {
                ref.read(databaseProvider).deleteVideoDubProject(id);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context).navVideoDub,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).uiDubVideoWithTTSFromSubtitleCues,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _createProject,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(AppLocalizations.of(context).uiNewProject),
          ),
        ],
      ),
    );
  }

  Future<void> _createProject() async {
    final banks = ref.read(voiceBanksStreamProvider).valueOrNull ?? [];
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

    final nameCtrl = TextEditingController();
    var selectedBankId = banks.first.id;

    final result = await showDialog<(String, String)?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).uiNewVideoDubProject),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).uiProjectName,
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).navVoiceBank,
                ),
                isExpanded: true,
                initialValue: selectedBankId,
                items: banks
                    .map(
                      (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => selectedBankId = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).uiCancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, (nameCtrl.text, selectedBankId)),
              child: Text(AppLocalizations.of(context).uiCreate),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.$1.trim().isNotEmpty) {
      final id = const Uuid().v4();
      final now = DateTime.now();
      await ref
          .read(databaseProvider)
          .insertVideoDubProject(
            db.VideoDubProjectsCompanion(
              id: Value(id),
              name: Value(result.$1.trim()),
              bankId: Value(result.$2),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      setState(() => _selectedProjectId = id);
    }
  }

  String _fileBaseName(String path) {
    final sep = path.contains('\\') ? '\\' : '/';
    final parts = path.split(sep);
    return parts.isEmpty ? path : parts.last;
  }
}
