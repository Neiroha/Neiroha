<div align="center">

<img src="assets/images/neiroha_logo.png" alt="Neiroha Logo" width="160" />

# Neiroha

**AI 音频中间件 & 配音工作站**

[![语言](https://img.shields.io/badge/语言-Dart%20%2F%20Flutter-0553B1?logo=flutter&logoColor=white)](https://flutter.dev)
[![平台](https://img.shields.io/badge/平台-Windows-0078D4?logo=windows&logoColor=white)](https://github.com/flutter/flutter)
[![发布状态](https://img.shields.io/badge/发布-预发布-orange)](https://github.com/Neiroha/Neiroha/releases)
[![版本](https://img.shields.io/badge/版本-0.1.0-blue)](https://github.com/Neiroha/Neiroha/releases)
[![许可证](https://img.shields.io/badge/许可证-MIT-green)](LICENSE)

[English](README.md) · [中文](README_zh.md)

</div>

---

<div align="center">
  <img src="assets/images/screenshot_overview.png" alt="Neiroha 总览" width="860" />
</div>

## Neiroha 是什么？

Neiroha 是一款 **基于 Flutter 的 Windows 桌面应用**，作为多种文字转语音（TTS）引擎的统一前端。它可以：

- 通过单一界面连接任意组合的 TTS 后端（云端或本地）。
- 构建命名 **语音角色** 库——每个角色绑定特定的提供商、音色、语速及可选的参考音频。
- 将角色整理到 **语音库（Voice Bank）** 中，并按项目切换。
- 通过内置的 **OpenAI 兼容 HTTP API** 对外提供语音合成服务，任何支持 OpenAI TTS 协议的工具无需修改即可直接接入。
- 覆盖从单次试听到长文本阅读、视频配音的多种生产模式：**快速 TTS**、**对话 TTS**、**段落 TTS**、**小说阅读器** 和 **视频配音**。
- 在设置页监控当前合成任务，包括正在运行/排队的 TTS 任务和 API 请求日志。

---

## 功能概览

| 模块 | 功能说明 |
|---|---|
| **提供商** | 连接 TTS 后端（OpenAI、Azure、GPT-SoVITS、CosyVoice、系统 TTS 等） |
| **语音角色** | 定义角色，绑定提供商、音色/模型、语速及参考音频 |
| **语音库** | 将角色分组管理；激活某个库使其在所有界面生效 |
| **快速 TTS** | 一键测试：选角色、输入文本、即时合成并播放 |
| **对话 TTS** | 多角色对话项目，支持 Telegram 风格的聊天气泡视图 |
| **段落 TTS** | 长篇叙事：粘贴脚本、拆分段落、批量合成 |
| **小说阅读器** | 导入 TXT/文件夹，使用缓存 TTS、预取、自动翻页和持续播放来朗读长篇小说 |
| **视频配音** | 导入视频/音频/字幕，为字幕生成 TTS，在轻量时间轴上编排并导出 |
| **任务页** | 在设置中查看当前排队/运行的 TTS、Provider 限流和最近失败 |
| **API 服务器** | 本地 OpenAI 兼容 HTTP 服务，默认仅回环地址，支持 API Key、CORS、限流和日志 |
| **存储 / 媒体工具** | 管理语音资产根目录、缺失文件扫描、音频归档清理、FFmpeg 检测和导出默认值 |

---

## 快速开始

### 环境要求

- Flutter SDK ≥ 3.11
- Windows 10/11（主要支持平台）
- 至少一个可访问的 TTS 后端（本地或局域网内均可）

### 从源码运行

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
```

---

## 使用指引

### 1. 配置提供商

进入侧边栏中的 **提供商（Providers）** 标签页。

点击 **+**（列表面板右上角）→ 填写名称并选择适配器类型：

| 适配器 | 适用场景 |
|---|---|
| **OpenAI TTS API 兼容** | OpenAI、KoboldCpp、Kokoro/XTTS（通过 OpenedAI-speech）、Orpheus 等 |
| **Azure 语音服务** | Microsoft Azure 语音服务 TTS |
| **GPT-SoVITS** | 本地 GPT-SoVITS 服务器（GptSoVITS v2 API） |
| **CosyVoice 原生** | 本地 CosyVoice 推理服务器 |
| **VoxCPM2 原生** | 本地 VoxCPM2 推理服务器 |
| **OpenAI Chat Completions TTS** | 通过 Chat Completions 接口输出音频的模型 |
| **Google Gemini TTS** | Google AI Studio Gemini TTS 模型 |
| **Windows 系统 TTS** | Windows SAPI 语音，无需服务器 |

根据所选提供商填写相应字段:

- **Base URL** — 例如本地 OpenAI 兼容服务器填 `http://localhost:8880/v1`，Azure 填区域名 `eastus` 或完整 URL。
- **API Key** — 若服务器无需鉴权则留空。
- **默认模型名** — 用于 GPT-SoVITS / CosyVoice；Azure/系统 TTS 忽略此项。

点击 **获取（Fetch）** 或 **全部获取（Fetch All）** 从提供商拉取可用模型/音色并缓存到本地。也可通过 **+ 添加** 手动录入。

点击 **保存**，然后拨动提供商行的开关将其 **启用**。点击 **健康检查** 确认连通性。

<div align="center">
  <img src="assets/images/screenshot_providers.png" alt="提供商配置页" width="860" />
</div>

---

### 2. 创建语音角色

进入 **语音库（Voice Bank）** 标签页，选择或创建一个语音库，然后点击 **New Character**。

填写：

- **名称** — 在整个应用中显示的名称。
- **提供商** — 选择一个已启用的提供商。
- **任务模式** — 决定显示哪些配置项：
  - *预设音色* — 从提供商音色列表中选择（如 `alloy`、`en-US-AriaNeural`）。
  - *音色克隆（带提示）* — 上传参考音频片段 + 提示文本，用于支持克隆的模型（GPT-SoVITS、CosyVoice）。
  - *音色设计* — 以自由格式指令发送给支持 `voice_instruction` 的模型（如 MiMo v2 TTS、Chat Completions TTS）。
- **语速** — 合成速度倍率（0.5 – 2.0）。
- **头像** — 可选图片，显示在聊天气泡中。

点击 **保存角色**。

---

### 3. 构建语音库

进入 **语音库（Voice Bank）** 标签页。

点击 **+ 新建库** → 填写名称 → 可以在当前语音库中直接创建角色，也可以从其他语音库导入已有角色。

点击目标库上的 **设为激活**。激活的语音库会作为项目创建和 API 音色/模型列表的默认音色池。

---

### 4. 快速 TTS

快速 TTS 位于 **语音库（Voice Bank）** 的角色检查器中。选择一个语音库和角色后，使用角色设置上方的快速测试面板。

1. 在当前语音库中选择一个角色。
2. 在快速测试输入框中输入文本。
3. 点击生成按钮。音频会通过共享队列合成、保存到磁盘并自动播放。
4. 生成结果会进入 Quick TTS 归档，方便后续复用和存储扫描。

<div align="center">
  <img src="assets/images/screenshot_quick_tts.png" alt="快速 TTS 页面" width="860" />
</div>

---

### 5. 对话 TTS

进入 **对话 TTS（Dialog TTS）** 标签页。适用于游戏对话或配音脚本等多角色音频制作场景。

#### 创建项目

点击 **新建项目** → 填写名称并选择语音库 → 点击 **创建**。

#### 添加对话行

在右侧面板底部的输入栏中：

1. 从 **音色** 下拉菜单选择角色。
2. 输入台词文本。
3. 点击 **发送**（→）。该行以聊天气泡形式出现。

逐行重复，按需切换角色。

#### 生成音频

点击 **全部生成** 合成所有尚无音频的对话行，按顺序处理；错误以气泡上的红色徽章标示。

点击任意气泡上的 ▶ 播放其音频，波形动画显示播放进度及已用/总时长。

<div align="center">
  <img src="assets/images/screenshot_dialog_tts.png" alt="对话 TTS 页面" width="860" />
</div>

---

### 6. 段落 TTS

进入 **段落 TTS（Phase TTS）** 标签页。适用于长篇叙事或有声书内容。

1. **创建项目** → 将完整脚本粘贴到文本框中。
2. 使用 **拆分** 按钮将脚本分割为段落（按空行或句子边界拆分）。
3. 审阅并编辑各段落。
4. 点击 **全部生成**，使用各段落分配的角色批量合成音频。
5. 从状态栏显示的输出目录导出或复制生成的音频文件。

---

### 7. 小说阅读器

进入 **小说阅读器（Novel Reader）** 标签页，用于长篇 TXT 阅读和缓存式 TTS 播放。

1. 从 TXT 文件或文件夹创建/导入小说项目。
2. 从项目绑定的语音库中选择旁白音色和对话音色。
3. 配置切片、跳过纯标点片段、预取数量、自动翻页和章节自动推进。
4. 点击播放后，阅读器会生成缺失音频、写入磁盘缓存，并通过共享 TTS 队列预取后续片段。
5. 如果希望切到设置/任务页时小说继续朗读，保持 **设置 → General → Keep TTS Running Across Screens** 开启。

Provider 并发数会作用在小说阅读器的生成任务上，但实际并发还取决于阅读器的预取/Ahead 数量。要跑满并发，请让预取数量不低于 Provider 并发数，并确认 RPM/TPM 等限流没有触发。

---

### 8. 视频配音

进入 **视频配音（Video Dub）** 标签页，可创建基于字幕的 TTS 配音项目。

1. 创建项目并选择语音库。
2. 导入视频到 V1；原视频音频会作为 A1 关联轨道。
3. 导入 SRT/LRC 字幕，然后为字幕 cue 生成 TTS。
4. 在时间轴上移动字幕和导入音频，必要时使用同步长度工具让生成语音贴合字幕时间窗，并可预览视频。
5. 使用 **设置 → Media Tools** 中配置的 FFmpeg 默认值导出音频或配音视频。

视频配音模块定位为单视频配音器，不替代完整剪辑软件，但覆盖常见的“字幕 → TTS → 导出配音”工作流。

---

### 9. 设置、任务和存储

**设置（Settings）** 标签页拆分为几个专门区域：

- **General** — 启动页面，以及切换 screen 时是否继续 TTS。
- **Tasks** — 当前运行/排队的 TTS 任务和最近完成/失败记录。
- **API Server** — 绑定地址、端口、API Key、CORS 白名单、限流、请求体大小限制和 API 日志。
- **Storage** — 语音资产根目录、缺失文件扫描和音频归档清理。
- **Media Tools** — FFmpeg 检测和音频/视频导出默认设置。

任务页展示的是全进程共享 TTS 调度器，Quick TTS、Dialog TTS、Phase TTS、Novel Reader、Video Dub 和本地 API Server 都会进入同一个队列。

---

### 10. API 服务器

Neiroha 暴露一个本地 HTTP 服务器，供外部工具（游戏、DAW、脚本等）通过标准 OpenAI 兼容接口调用 TTS。

#### 启动服务器

打开 **设置 → API Server** 并启动服务器。默认绑定地址为 **127.0.0.1**，默认端口为 **8976**，因此全新安装默认只允许本机访问。只有在明确需要局域网访问时，才将绑定地址改为 `0.0.0.0`。

安全和访问控制：

- 可选 API Key，通过 `Authorization: Bearer <key>` 或 `X-API-Key: <key>` 传入。
- 浏览器客户端使用 CORS origin 白名单。
- 支持按 IP 的每分钟请求预算和最大请求体大小限制。
- 可在设置中开启 API 日志输出；不会记录请求体和认证头。

#### 接口列表

| 方法 | 路径 | 说明 |
|---|---|---|
| `POST` | `/v1/audio/speech` | 语音合成（OpenAI 兼容） |
| `GET` | `/v1/audio/voices` | 列出可用语音角色 |
| `GET` | `/v1/models` | 列出可用提供商/模型 |
| `GET` | `/speakers` | 音色列表别名 |
| `GET` | `/health` | 健康检查——返回 `{"status":"ok"}` |

#### 请求示例

```bash
curl http://localhost:8976/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Default Bank",
    "voice": "Default Voice",
    "input": "你好，世界！",
    "response_format": "wav",
    "speed": 1.0
  }' \
  --output hello.wav
```

**字段说明：**

| 字段 | 类型 | 必填 | 备注 |
|---|---|---|---|
| `input` | string | 是 | 要合成的文本 |
| `voice` | string | 是 | 语音角色名称（与应用中配置的名称一致） |
| `model` | string | 否 | 语音库名称，用于限定音色查找范围；省略则全局搜索 |
| `response_format` | string | 否 | `wav`（默认）、`mp3`、`ogg`、`opus`、`pcm` |
| `speed` | number | 否 | 0.5 – 2.0，默认 `1.0` |

响应体为携带对应 `Content-Type` 头的原始音频字节流。

---

## 支持的提供商参考

### OpenAI TTS API 兼容

适用于任何实现了 `POST /v1/audio/speech` 的服务器。

```
Base URL: http://localhost:8880/v1
API Key:  （服务器指定，或留空）
Model:    tts-1  （或 tts-1-hd、kokoro 等）
```

### OpenAI Chat Completions TTS

适用于任何支持在 Chat Completions 接口中返回音频的模型（如 MiMo v2 TTS）。

### Azure 语音服务

```
Base URL: eastus              ← 裸区域名
          — 或 —
          https://eastus.tts.speech.microsoft.com
API Key:  <Ocp-Apim-Subscription-Key>
```

使用 **获取** 拉取 Azure 神经语音完整列表（约 400+ 个）。在角色配置中选择预设音色。

### GPT-SoVITS

```
Base URL: http://127.0.0.1:9880
```

将 **默认模型名** 设为 GPT-SoVITS 模型路径，或留空使用服务器默认值。角色应使用 *音色克隆（带提示）* 模式，并提供参考 `.wav` 及对应的文字记录。
相关仓库：[GptSoVITS](https://github.com/RVC-Boss/GPT-SoVITS)

### CosyVoice

```
Base URL: http://127.0.0.1:9880
```

兼容 CosyVoice 推理服务器。需用户自行上传音频配置克隆服务,相关程序可访问[CosyvoiceDesktop](https://github.com/Moeary/CosyVoiceDesktop)

### VoxCPM2 原生

```
Base URL: http://127.0.0.1:8000
```

兼容本地 VoxCPM2 风格推理服务器。后端支持时，角色可使用参考音频和可选语音指令。

### Google Gemini TTS

```
Base URL: https://generativelanguage.googleapis.com
Model:    gemini-2.5-flash-preview-tts
```

使用 Google AI Studio Gemini TTS 模型。在 Provider 中配置 API Key，并根据模型能力选择预设音色或指令式音色控制。

### Windows 系统 TTS

无需 URL 或密钥。自动获取已安装的 SAPI 语音。角色使用 *预设音色* 模式。

---

## 数据存储

所有设置、角色、语音库及历史记录均存储于以下 SQLite 数据库：

```
%APPDATA%\com.neiroha.neiroha\neiroha.db
```

生成的音频文件存储于：

```
%APPDATA%\com.neiroha.neiroha\voice_asset\quick_tts\        ← 快速 TTS 输出
%APPDATA%\com.neiroha.neiroha\voice_asset\phase_tts\        ← 段落 TTS 输出
%APPDATA%\com.neiroha.neiroha\voice_asset\dialog_tts\       ← 对话 TTS 输出
%APPDATA%\com.neiroha.neiroha\voice_asset\novel_reader\     ← 小说阅读器缓存
%APPDATA%\com.neiroha.neiroha\voice_asset\video_dub\        ← 视频配音生成媒体
%APPDATA%\com.neiroha.neiroha\voice_asset\voice_character_ref\ ← 角色参考音频
```

语音资产根目录可在 **设置 → Storage** 中修改。Neiroha 会为项目和角色保留稳定的文件夹 slug，因此重命名显示名称不会移动已有音频。

---

## 故障排除

| 现象 | 解决方案 |
|---|---|
| 健康检查失败 | 确认 Base URL 可访问且 API Key 正确 |
| 快速 TTS 无音色显示 | 激活一个包含至少一个已启用角色的语音库 |
| 音频可播放但显示 `--:--` 时长 | 首次播放时属正常现象——时长在第一次播放后自动更新 |
| 小说阅读并发看起来没生效 | 提高小说阅读器的预取/Ahead 数量，并检查 RPM/TPM 限流 |
| API 服务器在其他机器上访问不到 | 默认绑定 `127.0.0.1`；如需局域网访问请改为 `0.0.0.0` 并配置 API Key |
| 日志出现 `Platform channel threading` 警告 | 已在此版本修复——不再创建临时 AudioPlayer 实例 |
