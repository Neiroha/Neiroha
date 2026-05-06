# Local TTS API Lightweight Integration Guide

**Audience:** 后续接手的 AI / 开发者。  
**Goal:** 判断本地 TTS 后端是否应该继续拆成独立仓库，并指导把 CosyVoiceDesktop 中复用的 API 抽成 Neiroha 可直接连接的轻量 API 服务。  
**Primary target:** CosyVoice local API lightweight repo.  
**Secondary target:** GPT-SoVITS local launcher only if later 需要统一安装/启动体验。

Read this before touching code. Neiroha 主仓库已经有 TTS 适配器，真正要补的是本地模型服务的边界和 API 稳定性。

---

## 1. Recommendation

继续新建仓库，但只给“重型本地模型运行时”建仓库，不要把这些 Python/CUDA/模型依赖放进 Flutter 主项目。

建议仓库策略：

| 后端 | 建议 | 原因 |
|---|---|---|
| VoxCPM2 | 维持现有 `Neiroha/Neiroha-VoxCPM` | 已经是干净的外壳仓库模式：pixi 环境、上游 submodule、本地 FastAPI launcher、模型和 runtime 不入库 |
| CosyVoice | 新建 `Neiroha/Neiroha-CosyVoice-API` 或 `Neiroha/Neiroha-CosyVoice` | 当前 Neiroha 已依赖 CosyVoice 原生 API 形状，但 API 实现来自桌面 GUI 项目，应该抽成无 PyQt、无桌面状态耦合的轻量服务 |
| GPT-SoVITS | 暂时不必新建 | Neiroha 现在适配的是 GPT-SoVITS `api_v2.py` 风格 `/tts` 接口；只有当你想提供一键 pixi 环境、权重切换封装、固定启动脚本时，才建 `Neiroha-GPT-SoVITS-API` |

原则：Neiroha 主仓库只做统一前端和中间层；每个重型本地模型服务是可选外部进程，通过 HTTP 接入。

---

## 2. Current Neiroha Contract

不要从 UI 猜接口。以这些文件为准：

- `lib/data/adapters/tts_adapter.dart` - `TtsRequest` 统一请求对象和 `createAdapter()`
- `lib/data/adapters/cosyvoice_adapter.dart` - Neiroha 对 CosyVoice API 的实际调用
- `lib/data/adapters/gpt_sovits_adapter.dart` - GPT-SoVITS 的 `/tts` 适配
- `lib/data/adapters/voxcpm2_native_adapter.dart` - VoxCPM2 原生 API 参考
- `lib/domain/enums/adapter_type.dart` - Provider 类型、默认模型、是否查询模型/声音
- `lib/data/database/app_database.dart` - 默认 Provider seed
- `docs/api-zh.md` - 当前公开 API 说明

Neiroha 的统一模式只有三个：

| Neiroha `TaskMode` | 请求字段 | 本地后端常见术语 |
|---|---|---|
| `cloneWithPrompt` | `refAudioPath`, `promptText`, `promptLang` | zero_shot, clone, voice clone |
| `voiceDesign` | `voiceInstruction`, 可带参考音频 | instruct, instruction control, voice design |
| `presetVoice` | `presetVoiceName` | profile, speaker, voice id |

CosyVoice 轻量 API 的目标不是发明新协议，而是稳定满足 `CosyVoiceAdapter` 当前使用的协议。

---

## 3. CosyVoice API Must Match This Shape

Neiroha 的 `CosyVoiceAdapter` 会调用这些端点：

| Method | Path | 用途 |
|---|---|---|
| `GET` | `/health` | 健康检查 |
| `GET` | `/speakers` | SillyTavern 兼容 speaker 列表 |
| `GET` | `/cosyvoice/profiles` | Neiroha 创建角色时列出服务端 profile |
| `POST` | `/cosyvoice/speech` | JSON 合成，不上传参考音频 |
| `POST` | `/cosyvoice/speech/upload` | multipart 合成，上传 `prompt_audio` |

建议轻量 API 同时保留这些兼容端点，方便给其他工具用：

| Method | Path | 用途 |
|---|---|---|
| `GET` | `/v1/models` | OpenAI-style 模型列表 |
| `GET` | `/v1/audio/voices` | OpenAI-style 声音列表 |
| `POST` | `/v1/audio/speech` | OpenAI-style TTS |
| `GET` | `/cosyvoice/meta` | 能力说明，便于调试和文档生成 |

### JSON Synthesis

`POST /cosyvoice/speech`

```json
{
  "text": "要合成的文本",
  "mode": "zero_shot",
  "speed": 1.0,
  "response_format": "wav",
  "profile": "speaker_name",
  "prompt_text": "参考音频文本",
  "prompt_lang": "zh",
  "instruct_text": "用温柔平静的语气朗读"
}
```

Notes:

- `profile` 是服务端本地 profile id/name，不是 Neiroha 的 VoiceAsset id。
- 没有上传音频时，服务端必须能通过 `profile` 找到参考音频配置。
- 如果没有 `profile`，但请求带了 `prompt_audio_path`，服务端可以读取本机路径，但这只适合本机同盘运行，不适合远程客户端。

### Multipart Upload Synthesis

`POST /cosyvoice/speech/upload`

Form fields:

| Field | Required | Notes |
|---|---|---|
| `text` | yes | 要合成的文本 |
| `mode` | usually | `zero_shot`, `cross_lingual`, `instruct` |
| `prompt_audio` | yes for upload path | 上传的参考音频文件 |
| `prompt_text` | yes for `zero_shot` | 参考音频文字 |
| `instruct_text` | yes for `instruct` | 风格指令 |
| `prompt_lang` | optional | 预留语言字段 |
| `speed` | optional | 默认 `1.0` |
| `response_format` | optional | 默认 `wav` |

返回必须是原始音频 bytes，并设置合理的 `Content-Type`，例如 `audio/wav`。

---

## 4. New CosyVoice Lightweight Repo Shape

推荐仓库名：`Neiroha-CosyVoice-API`

推荐结构：

```text
.
├─ README.md
├─ LICENSE
├─ pixi.toml
├─ pixi.lock
├─ scripts/
│  ├─ launch_cosyvoice_api.py
│  ├─ download_modelscope_model.py
│  └─ adopt_model_cache.py
├─ cosyvoice_api/
│  ├─ __init__.py
│  ├─ app.py
│  ├─ runtime.py
│  ├─ profiles.py
│  ├─ schemas.py
│  └─ routers/
│     ├─ system.py
│     ├─ openai_compat.py
│     ├─ tavern.py
│     └─ cosyvoice_native.py
├─ config/
│  └─ profiles.example.json
├─ models/
├─ runtime/
└─ tests/
   ├─ test_contract.py
   └─ fixtures/
      └─ tiny_prompt.wav
```

`.gitignore` 必须排除：

```gitignore
.pixi/
models/
runtime/
runtime_tmp/
*.wav
*.mp3
*.flac
*.log
```

### Why Not Submodule CosyVoiceDesktop?

不要把 `Moeary/CosyVoiceDesktop` 当成长期运行依赖 submodule。它是 GUI 桌面应用，`main.py` 会初始化 PyQt；`pixi.toml` 也包含 PyQt/QFluentWidgets 等桌面依赖。轻量 API 应该只保留模型加载、profile 管理、FastAPI router、格式转换、上传临时文件清理。

可以参考或移植这些文件的思路，但要拆掉 GUI 耦合：

- `core/api.py`
- `core/api_routers/common.py`
- `core/api_routers/system.py`
- `core/api_routers/openai_compat.py`
- `core/api_routers/tavern.py`
- `core/api_routers/cosyvoice_native.py`
- `core/utils.py` 中的模型加载、temp dir、音频格式转换逻辑

如果直接复制代码，保留原项目 Apache-2.0 许可说明和 attribution。

---

## 5. Runtime Design

`cosyvoice_api/runtime.py` 应该集中管理模型生命周期，不要把全局变量散在 router 里。

建议接口：

```python
class CosyVoiceRuntime:
    def __init__(self, model_dir: str, wetext_dir: str, device: str = "auto", fp16: bool = False):
        ...

    def load(self) -> None:
        ...

    def health(self) -> dict:
        ...

    def synthesize(self, request: PreparedCosyVoiceRequest) -> tuple[bytes, str]:
        ...
```

启动参数建议：

```powershell
pixi run api
pixi run api -- --host 127.0.0.1 --port 9880
pixi run api -- --config config/profiles.json --preload-model
pixi run api -- --model-dir models/CosyVoice3-0.5B --wetext-dir models/wetext
```

`pixi.toml` 任务建议：

```toml
[tasks]
install = "python scripts/download_modelscope_model.py --model cosyvoice3 --model wetext"
api = "python scripts/launch_cosyvoice_api.py --host 127.0.0.1 --port 9880 --config config/profiles.json"
api-preload = "python scripts/launch_cosyvoice_api.py --host 127.0.0.1 --port 9880 --config config/profiles.json --preload-model"
```

Use lazy loading by default if startup time is painful; use `--preload-model` for Neiroha users who prefer first request not to block.

---

## 6. Profile Format

Keep profiles simple and portable:

```json
[
  {
    "id": "alice",
    "name": "alice",
    "mode": "zero_shot",
    "prompt_audio": "D:/voices/alice.wav",
    "prompt_text": "这是一段与参考音频一致的文本。",
    "prompt_lang": "zh",
    "instruct_text": ""
  }
]
```

Rules:

- `id`/`name` must be stable; Neiroha may store it as `presetVoiceName`.
- `prompt_audio` can be absolute or repo-relative. Resolve repo-relative paths against the API repo root.
- `mode` must normalize aliases to one of `zero_shot`, `cross_lingual`, `instruct`.
- `GET /cosyvoice/profiles` must return:

```json
{
  "object": "list",
  "data": [
    {
      "id": "alice",
      "name": "alice",
      "mode": "zero_shot",
      "mode_label": "语音克隆"
    }
  ]
}
```

---

## 7. Mode Mapping

CosyVoice lightweight API should normalize aliases at the service boundary.

| Canonical mode | Aliases | Required |
|---|---|---|
| `zero_shot` | `clone`, `voice_clone`, `clone_with_prompt`, `zero-shot` | `text`, `prompt_audio` or profile audio, `prompt_text` |
| `cross_lingual` | `cross-lingual`, `fine_grained`, `fine-grained` | `text`, `prompt_audio` or profile audio |
| `instruct` | `instruction`, `instruction_control`, `voice_design` | `text`, `prompt_audio` or profile audio, `instruct_text` |

Neiroha adapter behavior to preserve:

- If `voiceInstruction` exists, Neiroha routes as `instruct`.
- If `refAudioPath` exists, Neiroha uses `/cosyvoice/speech/upload`.
- If no `refAudioPath`, Neiroha uses `/cosyvoice/speech` and may send `profile`.
- Neiroha intentionally does not send `profile` in upload mode, because uploaded prompt audio should be self-contained.

---

## 8. Contract Tests

Add tests that can run without a real GPU by mocking `CosyVoiceRuntime.synthesize()`.

Minimum test cases:

1. `GET /health` returns status `ok`.
2. `GET /speakers` returns a list of `{name, voice_id}`.
3. `GET /v1/models` returns `cosyvoice-openai-tts`.
4. `GET /cosyvoice/profiles` returns profile ids and modes.
5. `POST /cosyvoice/speech` accepts profile JSON and returns audio bytes.
6. `POST /cosyvoice/speech/upload` accepts multipart `prompt_audio`.
7. `zero_shot` without `prompt_text` returns 400.
8. `instruct` without `instruct_text` returns 400.
9. Unsupported `response_format` returns 400 unless converter supports it.
10. Temp upload files are deleted after request success and failure.

Manual smoke tests:

```powershell
curl.exe http://127.0.0.1:9880/health
curl.exe http://127.0.0.1:9880/cosyvoice/profiles
curl.exe http://127.0.0.1:9880/speakers
```

JSON synthesis:

```powershell
curl.exe -X POST http://127.0.0.1:9880/cosyvoice/speech `
  -H "Content-Type: application/json" `
  -d "{\"text\":\"你好，这是一次测试。\",\"mode\":\"zero_shot\",\"profile\":\"alice\",\"response_format\":\"wav\"}" `
  --output out.wav
```

Upload synthesis:

```powershell
curl.exe -X POST http://127.0.0.1:9880/cosyvoice/speech/upload `
  -F "text=你好，这是一次上传参考音频的测试。" `
  -F "mode=zero_shot" `
  -F "prompt_text=参考音频对应的文本。" `
  -F "prompt_audio=@D:/voices/alice.wav" `
  -F "response_format=wav" `
  --output out_upload.wav
```

---

## 9. Neiroha Integration Steps

If the new CosyVoice API matches the contract above, Neiroha Flutter code does not need major changes.

Checklist inside Neiroha:

1. Provider screen: create or enable `CosyVoice Native`.
2. Base URL: `http://127.0.0.1:9880`.
3. Adapter type: `cosyvoice`.
4. Default model name: leave blank unless using it to force a mode (`zero_shot`, `cross_lingual`, `instruct`).
5. Character setup:
   - Clone: set task mode `cloneWithPrompt`, provide reference audio and prompt text.
   - Instruct: set task mode `voiceDesign`, provide instruction; reference audio may still be used.
   - Preset/profile: set task mode `presetVoice`, select or type server profile name.
6. Test from Voice Bank Quick TTS.
7. Test Neiroha local API passthrough: `POST /v1/audio/speech` to Neiroha with `model` as active voice bank and `voice` as character name.

Only modify Neiroha if one of these changes:

- Endpoint names change.
- Response body becomes JSON/base64 instead of raw audio bytes.
- Profile listing shape changes.
- You want the provider screen to auto-fetch CosyVoice profiles into ModelBindings. Today `AdapterType.cosyvoice.supportsVoiceQuery` is `false`, and character creation has dedicated profile fetching behavior.

---

## 10. GPT-SoVITS Position

Keep GPT-SoVITS simple for now.

Neiroha currently calls:

- `POST /tts`
- `GET /control` for health

Expected request fields:

```json
{
  "text": "要合成的文本",
  "text_lang": "zh",
  "ref_audio_path": "D:/voices/ref.wav",
  "prompt_text": "参考文本",
  "prompt_lang": "zh",
  "speed_factor": 1.0,
  "media_type": "wav",
  "text_split_method": "cut5",
  "batch_size": 1,
  "streaming_mode": false
}
```

Do not create a new GPT-SoVITS repo unless the goal is one of these:

- Pin a known-good GPT-SoVITS version and CUDA/Python environment.
- Provide a Neiroha-branded `pixi run api` workflow.
- Add OpenAI-compatible routes or upload routes that upstream does not provide.
- Hide upstream path/weight switching behind a stable launcher API.

If you do create it, mirror the VoxCPM pattern rather than editing Neiroha first.

---

## 11. What Not To Do

- Do not put CosyVoice/GPT-SoVITS/VoxCPM model weights in Neiroha.
- Do not add PyQt/QFluentWidgets dependencies to Neiroha or the CosyVoice lightweight API.
- Do not make Neiroha spawn and manage CUDA model processes as an implicit side effect of opening the app.
- Do not rename `/cosyvoice/speech` or `/cosyvoice/speech/upload` without updating `CosyVoiceAdapter`.
- Do not require profile registration for upload mode. Upload mode should be self-contained.
- Do not silently call ASR to infer prompt text unless the user explicitly enables it.

---

## 12. AI Implementation Order

For the next AI working on this:

1. Create `Neiroha-CosyVoice-API` under the Neiroha org.
2. Start from a clean Python FastAPI package, not from the PyQt desktop entrypoint.
3. Port or reimplement the minimum API router logic from CosyVoiceDesktop with license attribution.
4. Extract model loading into `CosyVoiceRuntime`.
5. Implement profile loading and mode normalization.
6. Add mocked contract tests first.
7. Add `pixi.toml` with Windows CUDA-first dependencies and no GUI packages.
8. Add README quick start and curl examples.
9. Run manual smoke tests against the real model.
10. Only then update Neiroha docs/README links from CosyVoiceDesktop to the new lightweight repo.

The important invariant: Neiroha should see CosyVoice exactly like any other HTTP TTS provider. The local model service can evolve internally, but its API contract should stay stable.

---

## 13. External References

- `Neiroha/Neiroha-VoxCPM`: https://github.com/Neiroha/Neiroha-VoxCPM
- VoxCPM launcher reference: https://github.com/Neiroha/Neiroha-VoxCPM/blob/main/scripts/launch_voxcpm.py
- VoxCPM pixi environment reference: https://github.com/Neiroha/Neiroha-VoxCPM/blob/main/pixi.toml
- `Moeary/CosyVoiceDesktop`: https://github.com/Moeary/CosyVoiceDesktop
- CosyVoiceDesktop API entrypoint: https://github.com/Moeary/CosyVoiceDesktop/blob/main/core/api.py
- CosyVoice native router: https://github.com/Moeary/CosyVoiceDesktop/blob/main/core/api_routers/cosyvoice_native.py
- CosyVoiceDesktop pixi environment: https://github.com/Moeary/CosyVoiceDesktop/blob/main/pixi.toml
