part of 'editor.dart';

extension _VideoDubEditorLayout on _VideoDubEditorState {
  Widget _buildBar(db.VideoDubProject project, int voiceCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to projects',
            onPressed: () => _back(project),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.movie_filter_rounded,
            color: AppTheme.accentColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _dirty ? '• ${project.name}' : project.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDim,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$voiceCount voices',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _exporting ? null : () => _exportAudio(project),
            icon: _exporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.audiotrack_rounded, size: 16),
            label: const Text('Export Audio'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: project.videoPath == null || _exporting
                ? null
                : () => _exportVideo(project),
            icon: _exporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined, size: 16),
            label: Text(_exporting ? 'Exporting…' : 'Export Video'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _save(project),
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSurface(db.VideoDubProject project) {
    if (project.videoPath == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.movie_outlined,
                size: 56,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 12),
              Text(
                'No video loaded',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Import a video onto the V1 track from the timeline.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: ExcludeSemantics(
        child: Video(controller: _controller, controls: NoVideoControls),
      ),
    );
  }

  Widget _buildTransport(db.VideoDubProject project) {
    final canPlay = project.videoPath != null;
    final durationMs = _duration.inMilliseconds.toDouble();
    final sliderMaxMs = durationMs.clamp(0.0, double.infinity).toDouble();
    final sliderValueMs = _position.inMilliseconds
        .toDouble()
        .clamp(0.0, sliderMaxMs)
        .toDouble();
    return ExcludeSemantics(
      child: Container(
        color: AppTheme.surfaceDim,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            IconButton(
              onPressed: canPlay
                  ? () async {
                      await _cuePlayer.stop();
                      _activeCueId = null;
                      await _player.seek(Duration.zero);
                    }
                  : null,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            IconButton(
              onPressed: canPlay ? () => _player.playOrPause() : null,
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(_position),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Slider(
                  min: 0,
                  max: sliderMaxMs,
                  value: sliderValueMs,
                  onChanged: canPlay && _duration.inMilliseconds > 0
                      ? (v) async {
                          await _cuePlayer.stop();
                          _activeCueId = null;
                          await _player.seek(Duration(milliseconds: v.round()));
                        }
                      : null,
                ),
              ),
            ),
            Text(
              _formatDuration(_duration),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(width: 12),
            // Mute original video audio (default on — dubbing use case).
            Tooltip(
              message: _muteVideoAudio
                  ? 'Original audio muted'
                  : 'Original audio on',
              child: IconButton(
                icon: Icon(
                  _muteVideoAudio
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  size: 18,
                ),
                onPressed: () async {
                  _updateState(() => _muteVideoAudio = !_muteVideoAudio);
                  // Invalidate the A1-gating latch so the next tick (or an
                  // immediate re-apply while paused) picks up the new state.
                  _a1Covers = null;
                  _applyA1Gating(_position.inMilliseconds);
                },
              ),
            ),
            Tooltip(
              message: _syncDub ? 'Dub playback synced' : 'Dub playback off',
              child: IconButton(
                icon: Icon(
                  _syncDub
                      ? Icons.record_voice_over_rounded
                      : Icons.voice_over_off_rounded,
                  size: 18,
                  color: _syncDub
                      ? AppTheme.accentColor
                      : Colors.white.withValues(alpha: 0.4),
                ),
                onPressed: () async {
                  _updateState(() => _syncDub = !_syncDub);
                  if (!_syncDub) {
                    await _cuePlayer.stop();
                    _activeCueId = null;
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitlePanel(
    db.VideoDubProject project,
    List<db.SubtitleCue> cues,
    List<db.VoiceAsset> bankAssets,
    Map<String, db.VoiceAsset> assetMap,
  ) {
    return Container(
      color: AppTheme.surfaceDim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: cue-bar actions, ordered (left → right):
          //   • Add cue (one-off)
          //   • Add Subtitles (bulk SRT/LRC import)
          //   • Export Subtitles (per-cue TTS audio + SRT folder)
          //   • Clear (destructive, last by convention)
          // Top bar carries only the project-wide Export Audio / Export
          // Video / Save buttons.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Text(
                  'Subtitles',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Add cue',
                  onPressed: () => _addCueDialog(project, cues),
                  icon: const Icon(Icons.add, size: 18),
                ),
                IconButton(
                  tooltip: 'Add subtitles (import SRT/LRC)',
                  onPressed: () => _importSubtitles(project, cues),
                  icon: const Icon(Icons.subtitles_outlined, size: 18),
                ),
                if (cues.isNotEmpty)
                  IconButton(
                    tooltip: 'Export subtitles + Single TTS audio',
                    onPressed: _exportingSubtitles
                        ? null
                        : () => _exportSubtitlesAndTts(project, cues),
                    icon: _exportingSubtitles
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.queue_music_rounded, size: 18),
                  ),
                if (cues.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear all cues',
                    onPressed: () => _confirmClearCues(project),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cues.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.subtitles_off_outlined,
                            size: 42,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No cues yet.\nImport an SRT/LRC file or add one manually.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    itemCount: cues.length,
                    itemBuilder: (_, i) {
                      final cue = cues[i];
                      return CueCard(
                        key: ValueKey(cue.id),
                        cue: cue,
                        index: i,
                        bankAssets: bankAssets,
                        isSelected: cue.id == _selectedCueId,
                        isGenerating: _generatingCueIds.contains(cue.id),
                        isPreviewing: _previewCueId == cue.id,
                        onTap: () async {
                          _updateState(() => _selectedCueId = cue.id);
                          await _cuePlayer.stop();
                          _activeCueId = null;
                          await _player.seek(
                            Duration(milliseconds: cue.startMs),
                          );
                        },
                        onVoiceChanged: (voiceId) =>
                            _updateCueVoice(cue, voiceId),
                        onGenerate: _generatingCueIds.contains(cue.id)
                            ? null
                            : () => _generateOne(project, cue, bankAssets),
                        onEdit: () => _editCueDialog(cue),
                        onDelete: () => _deleteCue(cue),
                        onPreview: () => _previewCue(cue),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: cues.isEmpty || _syncingCueLengths
                      ? null
                      : () => _syncCueLengthsToAudio(cues),
                  icon: _syncingCueLengths
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_alt_rounded, size: 16),
                  label: const Text('Sync cue lengths to TTS'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed:
                      cues.isEmpty || _generatingAll || bankAssets.isEmpty
                      ? null
                      : () => _generateAll(project, cues, bankAssets),
                  icon: _generatingAll
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Generate All'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
