# AI capability layer

One provider connection = one account. Capabilities hang off the connection,
models hang off capabilities. Domain types live in `lib/domain/ai/`
(`import 'package:neiroha/domain/ai/ai.dart'`).

```
core/        ProviderPlugin, ProviderConnection, ConnectionConfig, health,
             legacy TtsAdapter contract
registry/    plugin_registry (adapter type → plugin), capability_router,
             tts_adapter_factory (legacy createAdapter)
protocols/   transports shared by several vendors
  http/      speech HTTP streaming (io / web), error reasons
  audio/     WAV / PCM helpers
  openai/    OpenAI-shaped HTTP: Dio, transcriptions, speech, chat, responses
  realtime/  JSON WebSocket session + OpenAI transcription / translation /
             conversation sessions, Realtime-as-TTS stream
providers/<vendor>/
  <vendor>_plugin.dart       capabilities + catalog
  <vendor>_connection.dart   opens models, health check
  <capability>/              llm/ tts/ stt/ realtime/ translate/ vc/ vad/
providers/local/<engine>/    self-hosted engines (GPT-SoVITS, CosyVoice…)
providers/legacy/            bridge for adapter types without a full plugin
providers/on_device/         built-in engines, no account (VAD)
```

Rules: one model class per file; a vendor folder only imports `core/`,
`protocols/` and its own files; new vendors add a plugin and register it in
`registry/plugin_registry.dart`.
