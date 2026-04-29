# Code Review — `dev` 分支未提交修改

**审阅日期**：2026-04-28
**审阅范围**：当前 `git status` 中所有 modified 文件
**Base commit**：`d7ed4bd feat: refactor voice character components and dialogs for improved structure and readability`

## 修改概览

```
.metadata                                          |   8 +-
lib/data/adapters/chat_completions_tts_adapter.dart |  117 ++-
lib/data/adapters/tts_adapter.dart                 |   10 +-
lib/presentation/screens/provider_screen.dart      |  379 +++++++++++++-----
lib/presentation/widgets/voice_character/components.dart |  193 +++++----
lib/presentation/widgets/voice_character/create_character_dialog.dart |  280 +++++++++----
6 files changed, 743 insertions(+), 244 deletions(-)
```

主要内容：
- 在 `ChatCompletionsTtsAdapter` 中加入 MiMo V2.5 VoiceClone / VoiceDesign 支持
- `TtsRequest` 增加 `voiceClonePromptBase64` 与 `audioTagPrefix` 字段
- `provider_screen.dart` 把模型与声音的列表合并为分组视图，增加 TTS / 非 TTS 区分
- `create_character_dialog.dart` 根据所选模型类型（preset / clone / design）展示不同表单
- `VoiceCharacterVoiceSearchPicker` 改为下拉式（默认收起，点击展开）

---

## 严重问题

### 1. `provider_screen.dart:738` — TTS 模型分组下声音重复显示

```dart
..._models.where((m) => _isTtsModelKey(m.modelKey))
    .map((m) => _TtsModelGroup(
          model: m,
          voices: _voices,   // ← 每个 TTS 模型都收到完整 _voices 列表
          ...
        )),
```

如果一个 provider 有多个 TTS 模型（如 `MiMo-TTS-V2` 和 `MiMo-TTS-V2.5` 同时存在），**所有声音会在每个模型分组下重复显示**。声音应该按模型归属（例如通过 `modelKey` 前缀或绑定字段）过滤，否则用户会看到重复条目，且无法直观判断声音属于哪个模型。

### 2. `provider_screen.dart:720-749` — 仅有 voices 没有 models 时声音"消失"

```dart
if (_models.isEmpty && _voices.isEmpty)
  /* show empty state */
else ...[
  ..._models.where(_isTtsModelKey).map(...),
  ..._models.where(!_isTtsModelKey).map(...),
],
```

当 `_models` 为空但 `_voices` 非空（fetch 顺序错乱、用户先添加了 voice 而未添加 model 等）时，**else 分支两个 map 都产出空，导致已有的 voices 完全不显示**，用户找不到入口删除它们。建议在没有 TTS 模型但存在游离声音时单独渲染一个 "Unattached voices" 区块。

### 3. `chat_completions_tts_adapter.dart` — `dart:io` 导入与项目新增 `web/` 目录冲突（待评估）

新增 `import 'dart:io';` 用于读取本地参考音频文件。仓库刚新增了 `web/` 入口，但 `dart:io` 在 Web 平台不可用。如果计划支持 Web 构建，VoiceClone 路径需要走 `request.voiceClonePromptBase64`（已是 dataURL，不需要 `File`），并通过条件 import 拆分 IO。

当前其它适配器（cosyvoice、voxcpm2、system_tts）也已有同样问题，所以不是新引入的回归，但本次 PR 是把这条限制扩展到了又一个适配器。

---

## 中等问题

### 4. 集成尚未闭环：`voiceClonePromptBase64` / `audioTagPrefix` 字段没有写入端

```bash
grep voiceClonePromptBase64 / audioTagPrefix
```

这两个字段只在 `tts_adapter.dart`（声明）和 `chat_completions_tts_adapter.dart`（读取）出现，**没有任何调用方在构造 `TtsRequest` 时填充它们**。也就是说 VoiceClone 类型的角色保存进数据库后，实际合成时 `voiceClonePromptBase64` 仍为 null，会回退到 `refAudioPath` 读盘。需要在合成调用链（看起来在 voice_character pipeline）补齐字段传递。

### 5. `_isTtsModel` / `_isTtsModelKey` 重复定义

provider_screen.dart 和 create_character_dialog.dart 各有一份近乎相同的判定函数，未来加新关键字只改一处会出 bug。建议提取到公共 util（如 `lib/data/adapters/model_kind.dart`）。

### 6. `chat_completions_tts_adapter.dart:117` — 大文件先读后判

```dart
final bytes = await file.readAsBytes();
const maxCloneBytes = 10 * 1024 * 1024;
if (bytes.length > maxCloneBytes) throw ...
```

应先 `await file.length()` 再决定是否读入内存，否则一个 1GB 的误传文件会被整体加载后才报错。

### 7. `chat_completions_tts_adapter.dart` — 每次合成都重复 base64 编码

`_resolveVoiceCloneDataUrl` 每次 synthesize 都重新读文件并 base64。对长会话 / 批量合成是显著性能浪费。建议在角色构造时把 dataURL 计算一次缓存到 `voiceClonePromptBase64`。

---

## 小问题 / 可选优化

### 8. `provider_screen.dart:726` — 空态文案与判定不匹配

分支条件是 `_models.isEmpty && _voices.isEmpty`，文案却只说 `"No models yet"`，应改为 `"No models or voices yet."`。

### 9. `_NonTtsModelRow` 能力探测过于脆弱

```dart
RegExp(r'mimo-v2(\.5)?$').hasMatch(k) || k.contains('-vision') ...
```

未来出 `mimo-v3` / `gpt-5-omni` 都需要回来改这条。如果你们已经在 `ModelBinding` 里持久化了 capabilities，不如直接从数据读，而不是从模型名猜。

### 10. `components.dart:466` — 下拉外部点击不会关闭

`_VoiceSearchPickerState` 的 `_isOpen` 只能通过点击触发器或选项收起。点击页面其它区域不会关闭，长列表场景下 UX 略别扭。可用 `Focus` + `onFocusChange` 或 `OverlayPortal` 实现外部关闭。

### 11. `create_character_dialog.dart:174` — `_loadVoicesForModel` 内的 `_ttsModelType` 读取

```dart
if (mimoVoices.isNotEmpty && _ttsModelType == 'preset') voiceList = mimoVoices;
```

依赖调用方在调用前已经 `setState(_ttsModelType = ...)`，目前两个调用点都满足，但函数未把 type 作为参数传入，未来其他地方调用容易踩坑。建议把 `modelType` 作为参数显式传递。

### 12. `.metadata` 的平台清单

你删掉了 `android` / `linux` / `windows`，只保留 `root` 和 `web`。如果项目未来还会构建 Windows/Android，下次 `flutter create .` 会重新生成这些条目。如果这就是预期（项目只走 Web），没问题；否则这次提交需要回滚。

---

## 建议优先级

| 优先级 | 问题 | 影响 |
|--------|------|------|
| P0 | #1 声音重复 | Provider 配置面板可用性 |
| P0 | #2 voices 消失 | 数据丢失感知，用户无法删除 |
| P1 | #4 字段未闭环 | VoiceClone 功能实际不可用 |
| P1 | #3 dart:io / web | Web 构建可行性 |
| P2 | #5–#7 重构与性能 | 长期维护性 |
| P3 | #8–#12 体验细节 | 锦上添花 |
