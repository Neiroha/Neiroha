import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// Uniform view model for a project card so Phase TTS, Video Dub, etc. can
/// share the same grid. The owning screen maps its DB rows into these.
class ProjectCardData {
  final String id;
  final String name;
  final DateTime updatedAt;
  final IconData icon;
  final String? subtitle;

  const ProjectCardData({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.icon,
    this.subtitle,
  });
}

/// Searchable grid of project cards sorted by most-recently-modified.
///
/// Stateless w.r.t. the project data — the caller passes the full list and
/// receives `onOpen`/`onDelete` callbacks. A local search field filters
/// client-side; sorting happens here so every caller gets the same recency
/// behavior.
class ProjectCardGrid extends StatefulWidget {
  final List<ProjectCardData> projects;
  final ValueChanged<String> onOpen;
  final ValueChanged<ProjectCardData>? onSettings;
  final ValueChanged<String>? onDelete;
  final Future<void> Function(ProjectCardData project, String name)? onRename;
  final String? emptyLabel;

  const ProjectCardGrid({
    super.key,
    required this.projects,
    required this.onOpen,
    this.onSettings,
    this.onDelete,
    this.onRename,
    this.emptyLabel,
  });

  @override
  State<ProjectCardGrid> createState() => _ProjectCardGridState();
}

class _ProjectCardGridState extends State<ProjectCardGrid> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.projects]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? sorted
        : sorted
              .where((p) => p.name.toLowerCase().contains(q))
              .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).uiSearchProjects,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty(
                  q.isEmpty
                      ? widget.emptyLabel ??
                            AppLocalizations.of(context).uiNoProjectsYet
                      : AppLocalizations.of(context).uiNoMatches,
                )
              : _buildGrid(filtered),
        ),
      ],
    );
  }

  Widget _buildEmpty(String label) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildGrid(List<ProjectCardData> projects) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Target ~2 columns on typical window widths; scale up only on very
        // wide screens. Content width subtracts the outer 48px padding.
        final usable = constraints.maxWidth - 48;
        final crossAxisCount = (usable / 460).floor().clamp(1, 4).toInt();
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 160,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: projects.length,
          itemBuilder: (ctx, i) {
            final p = projects[i];
            return _ProjectCard(
              data: p,
              onTap: () => widget.onOpen(p.id),
              onSettings: widget.onSettings == null
                  ? null
                  : () => widget.onSettings!(p),
              onDelete: widget.onDelete == null
                  ? null
                  : () => widget.onDelete!(p.id),
              onRename: widget.onRename,
            );
          },
        );
      },
    );
  }
}

class _ProjectCard extends StatefulWidget {
  final ProjectCardData data;
  final VoidCallback onTap;
  final VoidCallback? onSettings;
  final VoidCallback? onDelete;
  final Future<void> Function(ProjectCardData project, String name)? onRename;

  const _ProjectCard({
    required this.data,
    required this.onTap,
    required this.onSettings,
    required this.onDelete,
    required this.onRename,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: _hovering ? AppTheme.surfaceBright : AppTheme.surfaceDim,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        d.icon,
                        size: 22,
                        color: AppTheme.accentColor,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        d.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.onSettings != null ||
                        widget.onDelete != null ||
                        widget.onRename != null)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        onSelected: (v) {
                          if (v == 'settings') widget.onSettings?.call();
                          if (v == 'delete') widget.onDelete?.call();
                          if (v == 'rename') unawaited(_renameProject());
                        },
                        itemBuilder: (_) => [
                          if (widget.onSettings != null)
                            PopupMenuItem(
                              value: 'settings',
                              child: Row(
                                children: [
                                  Icon(Icons.tune_rounded, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.of(context).navSettings,
                                  ),
                                ],
                              ),
                            )
                          else if (widget.onRename != null)
                            PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_rounded, size: 16),
                                  SizedBox(width: 8),
                                  Text(AppLocalizations.of(context).uiRename),
                                ],
                              ),
                            ),
                          if (widget.onSettings == null &&
                              widget.onDelete != null)
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_rounded,
                                    size: 16,
                                    color: Colors.redAccent,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.of(context).uiDelete,
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                const Spacer(),
                if (d.subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      d.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                Text(
                  _formatDate(d.updatedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _renameProject() async {
    final callback = widget.onRename;
    if (callback == null) return;
    final nameCtrl = TextEditingController(text: widget.data.name);
    final nextName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).uiRename),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).uiProjectName,
            ),
            onSubmitted: (value) => Navigator.pop(ctx, value),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).uiCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text),
            child: Text(AppLocalizations.of(context).uiRename),
          ),
        ],
      ),
    ).whenComplete(nameCtrl.dispose);
    final trimmed = nextName?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == widget.data.name) {
      return;
    }
    await callback(widget.data, trimmed);
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
