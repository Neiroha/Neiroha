<div align="center">

<img src="assets/images/neiroha_logo.png" alt="Neiroha Logo" width="150" />

# Neiroha

**AI 音频中间件与配音工作站**

[![语言](https://img.shields.io/badge/语言-Dart%20%2F%20Flutter-0553B1?logo=flutter&logoColor=white)](https://flutter.dev)
[![平台](https://img.shields.io/badge/平台-Windows%20%7C%20Linux%20%7C%20Android-0078D4)](https://flutter.dev)
[![版本](https://img.shields.io/badge/版本-v0.3.0-blue)](https://github.com/Neiroha/Neiroha/releases)
[![许可证：MIT](https://img.shields.io/badge/许可证-MIT-green)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/Neiroha/Neiroha?style=social)](https://github.com/Neiroha/Neiroha/stargazers)

[English](README.md) · [中文](README_zh.md) · [Wiki](https://neiroha.github.io/) · [API](docs/api-zh.md)

</div>

---

## 一个面向 AI 语音生产的工作台

Neiroha 是一个 Flutter 应用，面向需要大量角色音色、多种 TTS 引擎、长文本生成和配音项目的创作者。它的目标不是再做一个简单的输入框，而是把零散脚本、Web UI、文件夹和本地推理服务整理成一个可持续使用的工作流。

它把本地推理封装、云端语音 API、音色克隆、可复用角色、语音库、长文本旁白、对话生成、视频配音和本地 OpenAI 兼容 API 放进同一个操作界面。

## 为什么用它

| 强项 | 能解决什么 |
|---|---|
| **多引擎统一管理** | 在一个应用里使用 OpenAI 兼容 TTS、Azure Speech、Gemini TTS、GPT-SoVITS、CosyVoice、VoxCPM2、MiMo 风格 Chat TTS 和 Windows SAPI等 |
| **把参数变成角色** | 把服务商、模型、音色、语速、参考音频、提示文本、风格指令保存成可复用的语音角色 |
| **用语音库组织项目** | 一整套角色可以在脚本、小说、对话、视频配音和外部 API 调用之间复用。 |
| **为长任务设计** | 支持生成队列、音频缓存、小说预取、失败检查、任务监控和本地 GPU 后端的限流控制。 |
| **也能作为中间件** | 将当前激活的语音库暴露为本地 OpenAI 兼容 TTS API，让编辑器、Agent、脚本和外部工具直接调用。 |

## 功能亮点

### 服务商中枢

连接云端与本地 TTS 后端，拉取模型和音色，执行健康检查，设置并发与速率限制，把后端细节从创作流程里拆出去。

<div align="center">
  <img src="assets/images/screenshot_providers.png" alt="服务商管理界面" width="900" />
</div>

### 语音角色与语音库

把后端参数封装成可命名、可复用的角色。每个角色可以携带服务商、模型/音色、语速、参考音频、提示文本、风格指令和头像。语音库则负责把一整组角色带进不同项目。


<div align="center">
  <img src="assets/images/screenshot_overview.png" alt="语音角色与语音库" width="900" />
</div>

### 聊天对话TTS

用聊天式编辑器制作多角色对话，为每一行分配语音角色，按顺序生成缺失音频，并逐句回放检查。

<div align="center">
  <img src="assets/images/screenshot_dialog_tts.png" alt="Dialog TTS 界面" width="900" />
</div>

### 长文本朗读

拆分长脚本、分配角色、批量生成旁白，并在生成完成后合并导出音频。

<div align="center">
  <img src="assets/images/screenshot_phase_tts.png" alt="Phase TTS 界面" width="900" />
</div>

### 视频配音

导入视频和字幕，生成 TTS 片段，在轻量时间轴上对齐，并通过 FFmpeg 流程导出音频或视频。

<div align="center">
  <img src="assets/images/screenshot_video_tts.png" alt="Video Dub 界面" width="900" />
</div>

## 本地 API

Neiroha 也可以作为本地 OpenAI 兼容 TTS 服务运行，由当前激活的语音库提供模型和音色。这让它可以作为编辑器、Agent、脚本和其他工具的语音中间件。

完整接口见 [docs/api-zh.md](docs/api-zh.md)。安装、后端默认值、API Key、模型配置和使用教程放在 [Wiki](https://github.com/Neiroha/Neiroha/wiki)。

## 项目入口

- [Wiki](https://neiroha.github.io/)：安装、后端配置和使用教程。
- [API 文档](docs/api-zh.md)：本地 HTTP 集成说明。
- [Releases](https://github.com/Neiroha/Neiroha/releases)：发布包下载。


## 用户协议与免责声明

本项目可对接包括 CosyVoice、VoxCPM2、GPT-SoVITS 在内的开源及第三方语音能力，并遵循相关上游项目的许可证及使用规范。请在下载、部署或分发相关模型与服务前，阅读并遵守上游项目的官方条款。

用户在创作过程中应确保拥有使用输入文本、参考音频、角色素材及生成内容的合法权利，不得侵犯第三方的版权、肖像权、声音权益、隐私权或其他合法权益。

禁止将本项目用于任何违法、违规、欺骗、滥用、伤害他人或违背公共秩序与善良风俗的用途；如因违规使用导致损失或法律责任，均由用户自行承担。

项目提供的打包版本、脚本及相关资源仅供个人学习与研究使用，未经许可不得用于商业再发行、转售或二次打包牟利。

项目维护者保留依据法律法规、上游项目变化或社区反馈，随时更新、暂停或终止发布、服务、文档与支持的权利。

使用 Neiroha 即视为同意上述协议条款。若您不同意任何条款，请立即停止使用并删除相关文件。

## 项目统计

<div align="center">

<a href="https://star-history.com/#Neiroha/Neiroha&Date">
  <img src="https://api.star-history.com/svg?repos=Neiroha/Neiroha&type=Date" alt="Neiroha Star History" width="620" />
</a>

</div>
