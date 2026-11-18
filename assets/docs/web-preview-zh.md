# Neiroha Web

Web 版由主 Flutter 工程构建，沿用原版侧栏、Provider、音色库、角色编辑和快速试听。打开网页后，在「服务商」配置并启用 HTTP 服务，在「音色库」选择角色，输入文本后生成。试听卡片支持播放、下载和删除。

OpenAI 官方适配器的 Speech API 模型支持「自动：优先流式」。网页通过 Fetch 逐块读取 PCM，由 Web Audio 边收边播。点击停止会终止上游请求和当前播放，未完成的音频不会出现在历史里。完整生成后可从内存历史中重播或下载 WAV。其他网页适配器继续使用整段合成。

## 浏览器存储

- Provider 配置（含用户输入的 API Key）、模型和音色列表、角色、音色库及应用偏好使用原版 Drift schema。SQLite 在浏览器内运行，Drift 选择 OPFS 或共享 IndexedDB 持久层。数据按浏览器配置和站点来源隔离，清除站点数据也会清除配置。无法取得可安全持久化的存储时会显示提示。
- 生成的音频和快速试听历史留在当前标签页内存，最多保留 30 条或 32 MiB。刷新、关闭标签页会清空，需要留存的片段可通过卡片下载。

## 目录与构建产物

- 根目录的 `lib/` 是 Flutter 应用源码。Web 从 `lib/main.dart` 启动，复用原版界面、Drift 表和 TTS 服务，浏览器适配也位于各自职责对应的 `lib/` 模块。
- 根目录的 `web/` 是 Flutter 的平台入口和静态资源目录。`index.html` 负责加载 Flutter，`sqlite3.wasm` 和 `drift_worker.js` 是准备脚本生成的配套 SQLite 运行时，按锁定的 Drift 版本校验 SHA-256，并由 Git 忽略。
- `build/web/` 是完整的静态部署产物。构建会复制入口与 SQLite 运行时，并生成由 Dart 编译而来的 `main.dart.wasm`、JavaScript 回退入口和 Flutter 资源。

## 构建和本机验证

在仓库根目录使用 Flutter 3.47.7：

```powershell
flutter pub get
node scripts/tools/prepare_web_sqlite.mjs
flutter build web --wasm --release --no-web-resources-cdn
node scripts/tools/serve_web_preview.mjs
```

打开 [本机 Neiroha Web](http://127.0.0.1:8080/)。用 `NEIROHA_WEB_PORT` 可调整监听端口。准备脚本按 `pubspec.lock` 中的 Drift 版本下载并校验配套的 SQLite Wasm 和 worker。部署时使用 `build/web/` 的完整输出。托管端应为 `.wasm` 返回 `application/wasm`，为 `.mjs` 和 worker 返回 JavaScript MIME 类型。推荐配置 `Cross-Origin-Opener-Policy: same-origin` 和 `Cross-Origin-Embedder-Policy: require-corp`，以支持多线程渲染及 OPFS。详见 [Drift Web](https://drift.simonbinder.eu/platforms/web/) 和 [Flutter Web 部署](https://docs.flutter.dev/deployment/web)。

合成由浏览器直连配置的 Provider。跨源 Provider 需允许 Neiroha 站点的来源、请求方法和认证头（CORS）。使用 HTTPS 托管时，Provider 也应提供浏览器可访问的安全地址。浏览器合成支持可直连的 HTTP Provider 和无需本地参考文件的音色。

## 桌面功能

小说阅读、对话与长文本工程、视频配音、文件型素材库及本机 API/MCP 仍在桌面端使用。Web 界面保留导航入口并显示提示。参考文件、录音、FFmpeg、系统语音和 OpenAI Realtime 按平台禁用。
