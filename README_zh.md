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
- 支持三种生产模式：单次合成的 **快速 TTS**、多角色对话的 **对话 TTS**，以及适合叙事和有声书的 **段落 TTS**。

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
| **API 服务器** | 本地 HTTP 服务器，暴露 OpenAI 兼容的 `/v1/audio/speech` 接口 |

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
| **OpenAI Chat Completions TTS** | 通过 Chat Completions 接口输出音频的模型 |
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

进入 **语音角色（Voice Characters）** 标签页。

点击 **+ 新建角色** → 填写：

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

进入 **语音库（Voice Banks）** 标签页。

点击 **+ 新建库** → 填写名称 → 从右侧面板将角色拖入库中，或点击任意角色行上的 **添加到库**。

点击目标库上的 **设为激活**。同一时间只能有一个库处于激活状态（激活的库为快速 TTS 和对话 TTS 提供音色）。

---

### 4. 快速 TTS

进入 **快速 TTS（Quick TTS）** 标签页。

1. 从左侧面板选择角色（来自激活语音库的音色）。
2. 在底部输入栏输入文本。
3. 点击 **生成** 按钮（✨）。音频将被合成、保存到磁盘并自动播放。
4. 历史合成记录以卡片形式显示，含波形和时长。点击 ▶ 可重播任意条目。
5. 点击右上角 **全部删除** 清空历史记录。

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

### 7. API 服务器

Neiroha 暴露一个本地 HTTP 服务器，供外部工具（游戏、DAW、脚本等）通过标准 OpenAI 兼容接口调用 TTS。

#### 启动服务器

打开 **设置** → 打开 **API 服务器** 开关。默认端口为 **8976**。

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
%APPDATA%\com.neiroha.neiroha\quick_tts\      ← 快速 TTS 输出
%APPDATA%\com.neiroha.neiroha\dialog_tts\     ← 对话 TTS 输出
```

---

## 故障排除

| 现象 | 解决方案 |
|---|---|
| 健康检查失败 | 确认 Base URL 可访问且 API Key 正确 |
| 快速 TTS 无音色显示 | 激活一个包含至少一个已启用角色的语音库 |
| 音频可播放但显示 `--:--` 时长 | 首次播放时属正常现象——时长在第一次播放后自动更新 |
| 日志出现 `Platform channel threading` 警告 | 已在此版本修复——不再创建临时 AudioPlayer 实例 |
