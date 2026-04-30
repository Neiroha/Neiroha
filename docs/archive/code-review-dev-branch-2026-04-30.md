# Code Review — dev branch uncommitted changes (2026-04-30)

针对 `dev` 分支当前 working tree 的未提交修改的质量评估。

## Scope

| 类别 | 文件数 | 备注 |
| --- | --- | --- |
| Modified | 14 | 适配器、数据库、UI、providers |
| Deleted | 4 | `role_assignment_service` / `role_mapping_file` / `llm_config` / `phase_tts/action_bar` |
| Added (untracked) | 6 | `phase_segment_settings_file` / `split_rules_service` / `phase_tts/exporter` / `script_workspace` / `segment_voice_panel` / `split_rules_dialog` |

`git diff --stat`: **+813 / −1003**，整体属于"功能重构 + 旧代码清理"。

`flutter analyze lib/` 干净，无 warning/error。

## 改动总览

### 1. Phase TTS 编辑器整体重构（核心）

**意图**：把"脚本输入 + 整段切分按钮"从顶栏剥离到左面板的工具栏，右面板专做句级配音/合成；新增句级 instruction 覆盖、退出脏检查、批量播放、导出合并音频。

涉及：
- `lib/presentation/screens/phase_tts_screen.dart`：从 `ConsumerWidget` 改为带状态管理的 ConsumerStatefulWidget；新增 `_dirty / _confirmLeave / _back / _saveProject / _playAll / _exportMerged`，并把切分按规则化（`SplitRule`）。
- `lib/presentation/screens/app_shell.dart`：通过 `PhaseTtsExitGuard` 回调把"切 Tab 时检查未保存"的逻辑挂到顶层。
- 新增 `widgets/phase_tts/script_workspace.dart`、`widgets/phase_tts/segment_voice_panel.dart`、`widgets/phase_tts/split_rules_dialog.dart`。
- 新增 `presentation/actions/phase_tts/exporter.dart`：把所有合成音轨用 ffmpeg `concat` 拼成一个文件导出。
- `lib/data/services/phase_segment_settings_file.dart`：项目目录下 `phase_segment_settings.json`，存每句的 `voiceInstruction` / `audioTagPrefix`。

### 2. 音频/适配器层

- `cosyvoice_adapter.dart`：当 `request.voiceInstruction` 非空时强制走 `instruct` 模式，覆盖 voice asset 上保存的 `zero_shot / cross_lingual`。**修复**了"句级 instruction 在 zero-shot 角色上不生效"的语义 bug。
- `tts_adapter.dart`：注释更新（标注 `voiceInstruction` 现在覆盖的适配器范围 = MiMo / CosyVoice / VoxCPM2 / Gemini）。
- `tts_provider.g.dart`：`AdapterType` 映射补上 `geminiTts`（之前漏了）。

### 3. 存储/Providers

- `ffmpeg_service.dart`：新增 `concatAudio()`，使用 concat demuxer + 临时 listing 文件，处理反斜杠 / 单引号转义；首次失败自动用 `_audioCodecForExt` 重试 re-encode；finally 清理临时文件。
- `path_service.dart`：`phaseTtsRoleMappingFile()` 替换为 `phaseTtsSegmentSettingsFile()`。其他改动是 `dart format` 噪声。
- `data/storage/split_rules_service.dart`（新）：`SplitRule` 模型 + JSON 写入 `AppSettings`（不走 schema 迁移，存进 `split_rules.list` key）。内置 3 条规则：段落 / 中英文句末 / 中英文引号闭合。
- `providers/app_providers.dart`：移除 `llmConfigServiceProvider` / `roleMappingFileServiceProvider`，新增 `splitRulesServiceProvider` / `splitRulesProvider` / `phaseSegmentSettingsFileServiceProvider`。其他大量改动是格式化噪声。
- `providers/playback_provider.dart`：`playSequenceFrom()` 现在可被 `_cancelActiveSequence()` 中断；新增 `phaseTtsPlaybackSource` 标签，让 PersistentAudioBar 能按 source 过滤。

### 4. 数据库

- `tables.dart` / `app_database.dart` / `app_database.g.dart`：`PhaseTtsSegments` 新增可空列 `speaker_label`，schema 15 → 16。
- 注释明确"reserved for future multi-role workflows"，**当前代码没有读写它**。

### 5. 删除

| 文件 | 说明 |
| --- | --- |
| `data/services/role_assignment_service.dart` | LLM 角色分配旧实现 |
| `data/services/role_mapping_file.dart` | role_mapping.json 读写 |
| `data/storage/llm_config.dart` | 关联的 LLM 配置存储 |
| `presentation/widgets/phase_tts/action_bar.dart` | 旧底部 ActionBar，被 `SegmentVoicePanel` 内联取代 |

`grep` 已确认源码内无残留引用，仅 `docs/` 中有历史描述。

## 质量评估

### ✅ 做得好的部分

- **CosyVoice 模式选择**修复，逻辑正确：per-call instruction 优先，否则按 modelName，否则推断。
- **退出守卫**：`AppShell` 拦截 Tab 切换、`_back` 拦截返回按钮，dirty=true 时弹三选项 dialog，不会静默丢失编辑。
- **ffmpeg concat 转义**：`'\''` 处理单引号、正斜杠归一化反斜杠 — 在 Windows 上常被忽略的两个坑都覆盖了。
- **顺序播放可取消**：`_sequenceRunId` + `Completer` 配合，开始新播放时上一组立刻停。
- **`SplitRule` 抽象**：内置规则可禁用但不能删；用户规则保存时校验正则；解析失败优雅回退到"整段一句"。**没有走 DB 迁移**，存 `AppSettings` 是合理决定。
- **Gemini adapter 类型补全**：之前 `tts_provider.g.dart` 漏掉 `geminiTts` 是隐藏 bug，这次顺手修了。
- `flutter analyze` 全绿。

### 🔴 必须修复后再提交

1. **死代码：`segment_panel.dart` 和 `segment_card.dart`**
   两个文件都在 diff 中（修改了 `resolveVoice` 签名等），但已无任何外部 import — 只剩 `segment_panel` import `segment_card`。新代码全部走 `SegmentVoicePanel`。
   建议：直接 `git rm` 这两个文件，不要把已死代码的修改一起带进 commit。

2. **`.claude/settings.local.json`** 末尾混了一个空格 + 缺换行。这种本地无意编辑应当 `git checkout -- .claude/settings.local.json` 还原，不要带进 commit。

### 🟡 建议关注（不阻断提交，但值得讨论）

3. **Schema 15 → 16 + 破坏性 `onUpgrade`**
   `app_database.dart` 的 `onUpgrade` 仍然是"按 FK 反序 drop 全表 + `createAll`"，意味着 v15 用户升级到 v16 会**丢全部项目/语音库**。
   - 如果项目仍处于"开发期数据可丢"阶段：保持现状是 OK 的，但要在发版 changelog 显式提示。
   - 如果已有外部用户：应该改为 `m.addColumn(phaseTtsSegments, phaseTtsSegments.speakerLabel)` —— 这次 schema 变化只新增了一个可空列，刚好可以做无损迁移。`docs/research/mimo-llm-asr-architecture.md` 第 396 / 1581 行已经写过这条迁移示例，可以直接抄。

4. **`speakerLabel` 当前未被任何代码读/写**
   YAGNI：迁移已花费的"破坏全表数据"成本是为了一个还没上线的 multi-role 功能。考虑等真正接入 LLM 角色分配时再加列；或者保留列但配真正的 `addColumn` 迁移以避免空赔本。

5. **`_loadSegmentSettings` 在 `_generateAll` 循环内重复读盘**
   `phase_tts_screen.dart` 的 `_generateOne` 每次合成前都 `await _loadSegmentSettings(project)`，对 100 段会读 100 次 JSON 文件。建议在 `_generateAll` 入口读一次、传 `Map<String, SegmentVoiceSettings>` 进去。

6. **`SegmentVoicePanel.dispose()` 异步落盘**
   `dispose()` 里 `unawaited(service.save(...))` 在 `_saveTimer?.cancel()` 之后，但 timer 早已触发的写入不会被 cancel。`save` 写整个 JSON 是幂等的，竞态后果不大，但严格说应改成"先 await pending write，再做 final save"。

7. **格式化噪声**
   `app_providers.dart`、`path_service.dart`、`segment_panel.dart`、`segment_card.dart`、phase_tts_screen.dart 大量行变化是 `dart format` 默认 80 列回流（链式调用换行 / collection 多行展开）。功能改动 + 格式化混在一个 commit 里 review 成本会显著上升。建议下次先单独提一个 `chore: dart format` commit，再做功能改动。

## 提交建议

**当前状态**：⚠️ 建议**修复 #1 / #2 后再提交**。功能本身质量过关，但携带死代码+本地配置文件杂质会污染历史。

**推荐拆分为 2~3 个 commit**：

```
1. chore: remove obsolete role-assignment / llm-config / action-bar
   - git rm 4 个删除文件 + segment_panel/segment_card

2. feat(phase-tts): per-segment voice instructions + merged export + exit guard
   - 主要 UI/逻辑改动 + 新增的 6 个文件
   - cosyvoice instruct 路由修复
   - playback sequence cancel
   - ffmpeg concatAudio
   - 还原 .claude/settings.local.json

3. feat(db): reserve speaker_label column for multi-role  ← 可选
   - tables.dart / app_database.dart / app_database.g.dart
   - 把 onUpgrade 改成 addColumn 而不是 drop 全表
   - 或者：等到 multi-role 功能真接入时再加
```

如果不想拆 commit，最低限度也要把 #1 / #2 处理掉再 `git add`。

---

**Reviewer**: Claude (Opus 4.7)
**Date**: 2026-04-30
**Branch**: `dev` (working tree, 未 staged)
**Commit hashes**: HEAD = `2195547`
