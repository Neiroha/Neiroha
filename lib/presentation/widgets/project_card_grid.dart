import 'package:flutter/material.dart';
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
  final ValueChanged<String>? onDelete;
  final String emptyLabel;

  const ProjectCardGrid({
    super.key,
    required this.projects,
    required this.onOpen,
    this.onDelete,
    this.emptyLabel = 'No projects yet',
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
                hintText: 'Search projects',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 18, color: Colors.white.withValues(alpha: 0.4)),
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
                    horizontal: 12, vertical: 0),
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty(q.isEmpty ? widget.emptyLabel : 'No matches')
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
              onDelete: widget.onDelete == null
                  ? null
                  : () => widget.onDelete!(p.id),
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
  final VoidCallback? onDelete;

  const _ProjectCard({
    required this.data,
    required this.onTap,
    required this.onDelete,
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
        color: _hovering
            ? AppTheme.surfaceBright
            : AppTheme.surfaceDim,
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
                      child: Icon(d.icon,
                          size: 22, color: AppTheme.accentColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        d.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (widget.onDelete != null)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: Icon(Icons.more_vert_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.4)),
                        onSelected: (v) {
                          if (v == 'delete') widget.onDelete?.call();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(color: Colors.redAccent)),
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

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
