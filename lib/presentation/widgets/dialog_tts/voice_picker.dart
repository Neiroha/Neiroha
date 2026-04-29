import 'dart:io';

import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';

/// Searchable, scrollable list of voices in a project's bank.
///
/// Tapping a voice fires [onPickVoice] with its id (typically used to set
/// the active input voice). A small badge next to each voice shows how
/// many lines in the project currently use that voice.
class VoicePicker extends StatefulWidget {
  final List<db.VoiceAsset> assets;
  final String? activeVoiceId;
  final List<db.DialogTtsLine> lines;
  final ValueChanged<String> onPickVoice;

  const VoicePicker({
    super.key,
    required this.assets,
    required this.activeVoiceId,
    required this.lines,
    required this.onPickVoice,
  });

  @override
  State<VoicePicker> createState() => _VoicePickerState();
}

class _VoicePickerState extends State<VoicePicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.assets
        : widget.assets
            .where((a) => a.name.toLowerCase().contains(q))
            .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: [
              Text(
                'VOICES IN BANK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.assets.length}',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.3)),
              ),
            ],
          ),
        ),
        if (widget.assets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search voices',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.4)),
                  prefixIconConstraints: const BoxConstraints(
                      minWidth: 28, minHeight: 28),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 14),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 28, minHeight: 28),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                ),
              ),
            ),
          ),
        Expanded(
          child: widget.assets.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Text(
                    'No voices in this bank. Add voices in Voice Bank.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12),
                  ),
                )
              : filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No matches',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final a = filtered[i];
                        return _VoiceTile(
                          asset: a,
                          selected: a.id == widget.activeVoiceId,
                          lineCount: widget.lines
                              .where((l) => l.voiceAssetId == a.id)
                              .length,
                          onTap: () => widget.onPickVoice(a.id),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _VoiceTile extends StatelessWidget {
  final db.VoiceAsset asset;
  final bool selected;
  final int lineCount;
  final VoidCallback onTap;

  const _VoiceTile({
    required this.asset,
    required this.selected,
    required this.lineCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar =
        asset.avatarPath != null && File(asset.avatarPath!).existsSync();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? AppTheme.accentColor.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      AppTheme.accentColor.withValues(alpha: 0.2),
                  backgroundImage:
                      hasAvatar ? FileImage(File(asset.avatarPath!)) : null,
                  child: hasAvatar
                      ? null
                      : Text(
                          asset.name.isNotEmpty
                              ? asset.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    asset.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? AppTheme.accentColor
                          : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                if (lineCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDim,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$lineCount',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
