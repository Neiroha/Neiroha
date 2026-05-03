# Fix — MiMo TTS UI 收口 + Web 兼容铺路

**日期**：2026-04-28
**分支**：`dev`
**触发**：`code-review-dev-branch-2026-04-28.md` 中 P0 问题 + UI 反馈"多 TTS 模型/不同音色集"

## 改了哪些

### `lib/data/adapters/chat_completions_tts_adapter.dart`

1. **`refAudioPath` 兼收文件路径或 dataURL**
   ```dart
   if (refPath.startsWith('data:audio/')) return refPath;
   ```
   这条让 Web 路径变成可行——dialog 端如果在保存阶段把上传的音频预编码成 `data:audio/...;base64,...`，adapter 不再走 `dart:io File` 读盘。Native 端继续用文件路径，行为不变。

2. **大文件先判尺寸再读**
   ```dart
   final length = await file.length();
   if (length > _maxCloneBytes) throw ArgumentError(...);
   final bytes = await file.readAsBytes();
   ```
   误传 1GB wav 不会再吃满内存才报错。

3. `_maxCloneBytes` 抽成静态常量。

### `lib/presentation/screens/provider_screen.dart`

**问题**：原 `_TtsModelGroup` 把 `_voices` 整个传给每个 TTS 模型，多 TTS 模型时声音重复显示；且 schema 本来就没有 model→voice 关系，嵌套是误导。

**修复方案**：
1. `_TtsModelGroup` → `_TtsModelRow`，**不再嵌套 voices**。
2. **TTS 模型行可展开**——展开后显示该模型的内置音色列表（通过 `ChatCompletionsTtsAdapter.builtInVoicesForMimoModel` 查），以 chip 形式平铺。MiMo V2 显示 3 个，V2.5 显示 9 个，未识别的模型不展开。这样多 TTS 模型并存（如 MiMo V2 + V2.5）时各自显示自己的音色集，不会混淆。
3. 用户手动 fetch / Add 的额外音色（`_voices`）独立成 **Custom Voices** 段，flat 列表。MiMo 通常这段为空。
4. 空态：`_models` 与 `_voices` 都空时显示 `'No models or voices yet.'`；**只有 voices 没有 models 时也能正常渲染 Custom Voices 段**（之前会消失）。

### 故意没动

- **Schema 没加 `voiceClonePromptBase64` / `audioTagPrefix` 列**——加列要重生 15k 行 `app_database.g.dart` + freezed 文件，且和 in-flight 的合成链路改造冲突。靠 `refAudioPath` 兼收 dataURL 的折中方案，零迁移、向后兼容。
- **`api_server.dart` 的 `TtsRequest` 构造没填 `voiceClonePromptBase64`**——留给合成链路收尾时一起改。
- **`_isTtsModelKey` / `_isTtsModel` 重复定义没合并**——跨文件抽 util 是另一条独立的清洁活儿。

## 验证

- `flutter analyze lib/` —— No issues found
- `flutter run -d windows` —— 启动正常

## 后续 follow-up（建议）

1. **dialog 端预编码 dataURL**：上传 ref 音频时直接 base64 编码塞进 `refAudioPath`（dataURL 形式），完全脱离 `dart:io File`。Web 部署时这是必经之路。
2. **`api_server.dart`**：保存合成链路改造时，把 `voiceClonePromptBase64` / `audioTagPrefix` 串起来。即便不加新列，也可以判断 `asset.refAudioPath` 是否 `data:` 开头来选填字段。
3. **抽 `model_kind.dart` util**：把 `_isTtsModelKey` / `_detectTtsModelType` 集中到一处。
4. **`_NonTtsModelRow._capabilities`** 启发式现在还是字符串猜（`gpt-4o`、`mimo-v2.5`、`-vision`）。如果 `ModelBinding` 后面会持久化能力字段，这里换成读字段。
