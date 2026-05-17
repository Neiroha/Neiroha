# 免费 / 试用 / 计划型 TTS API 盘点（排除 Azure）

> 最后核对时间：2026-04-26  
> 范围：只看**官方文档 / 官方定价页**；Azure 按你的要求排除。  
> 说明：这里把“免费”拆成三类，避免把永久免费、一次性赠送、以及订阅计划内额度混在一起。
>
> - **免费档**：官方明确给了持续免费额度或免费档。
> - **试用档**：官方明确给了新用户试用额度、赠送 credits、或限时试用。
> - **计划档**：不算严格免费，但官方把 TTS 配额塞进订阅计划里；你特别提到的 `Token Plan / Coding Plan` 归这类。

## 先给结论：最值得先接的顺序

如果目标是“我用别的模型一个个去实现”，我建议先按这个顺序：

1. **SiliconFlow TTS**
   - 原因：官方是 OpenAI 风格 `/v1/audio/speech`，最接近现有 `openAiTts` 适配路径。
   - 成本：新用户赠送 `14 元` 额度，足够先打样。
2. **腾讯云 TTS**
   - 原因：明确写了 `800 万字符 / 3 个月`，国内免费量很大。
   - 代价：需要走腾讯云鉴权，不是 OpenAI 兼容。
3. **阿里云百炼（Qwen-TTS / CosyVoice / Sambert）**
   - 原因：免费额度写得比较清楚，中文生态也全。
   - 备注：不同模型接口风格不完全一样，别把它们当成一个端点。
4. **Google Gemini API TTS**
   - 原因：AI Studio 免费档能直接试，适合做“可控情绪 / 指令式 TTS”。
   - 代价：不是 `/audio/speech` 风格，要单独做 adapter。
5. **ElevenLabs / Deepgram / Cartesia / Hume**
   - 原因：质量、延迟、情绪控制各有长处。
   - 代价：免费量普遍没国内云大，但很适合做标杆适配。

---

## 海外：明确有免费档或试用额度的 TTS API

| 厂商 | 产品 / API | 免费类型 | 2026-04-26 可用额度 | 接口形态 | 对 Neiroha 的实现建议 | 备注 | 官方 |
|---|---|---|---|---|---|---|---|
| Google | Gemini API Native TTS (`gemini-2.5-flash-preview-tts`) | 免费档 | 官方 free tier：`3 RPM / 10,000 TPM / 15 RPD`；价格页标注 free tier 下输入/输出免费 | Gemini API REST / SDK | **新建 custom adapter** | 适合做指令式 TTS；预览版；和 Google Cloud TTS 不是一回事 | [Speech docs](https://ai.google.dev/gemini-api/docs/speech-generation) / [Pricing](https://ai.google.dev/pricing) / [Quota](https://ai.google.dev/gemini-api/docs/quota) |
| Google Cloud | Text-to-Speech | 免费档 + 新客 credits | 定价页显示 `Chirp 3 HD` 有 `1M chars / 月` 免费用量；新客最多 `US$300` credits；但需启用 billing | Cloud REST / SDK | **新建 custom adapter** | 这是 Cloud TTS，不是 Gemini TTS；官方明确说要开 billing | [Product](https://cloud.google.com/text-to-speech) / [Pricing](https://cloud.google.com/text-to-speech/pricing) |
| AWS | Amazon Polly | 试用档 + 新客 credits | 前 `12` 个月：Standard `5M chars / 月`、Neural `1M / 月`、Long-Form `500k / 月`、Generative `100k / 月`；另有新客最多 `US$200` Free Tier credits | AWS API / SDK | **新建 custom adapter** | 免费量非常大，适合做长文本播报基线 | [Pricing](https://aws.amazon.com/polly/pricing) |
| IBM | Watson Text to Speech | 免费档 | Lite：`10,000 chars / 月` | IBM Cloud API | **新建 custom adapter** | 免费量不大，但文档和产品很稳定 | [Product / plan](https://www.ibm.com/products/text-to-speech) / [Cloud catalog](https://cloud.ibm.com/catalog/services/text-to-speech) |
| ElevenLabs | TTS API | 免费档 | Free 计划 `10k credits / 月`；API 价目页对应 Flash/Turbo 含 `20,000 chars`、Multilingual 含 `10,000 chars` | REST API | **新建 custom adapter** | 官方文档还写了：free tier **API 不能用 voice library** | [TTS docs](https://elevenlabs.io/docs/overview/capabilities/text-to-speech) / [API pricing](https://elevenlabs.io/pricing/api/) |
| Hume | Octave TTS | 免费档 | Free：`10,000 chars / 月`（约 10 分钟） | REST API | **新建 custom adapter** | 偏“情绪 / 表达力”路线，很适合做对照组 | [Pricing](https://www.hume.ai/pricing) / [TTS docs](https://dev.hume.ai/docs/text-to-speech-tts/overview) |
| Deepgram | Aura TTS | 试用档 | `US$200` 免费 credit；官方写明 `No credit card required` | REST + WebSocket | **新建 custom adapter** | 低延迟流式能力强，适合做实时播放场景 | [Pricing](https://deepgram.com/pricing) / [TTS getting started](https://developers.deepgram.com/docs/text-to-speech) |
| Cartesia | Sonic TTS | 免费档 | Free：`20K credits for models`；定价页写 TTS 为 `1 credit / character`，约等于 `20,000 chars` | Bytes / SSE / WebSocket | **新建 custom adapter** | 官方给了 bytes / SSE / WS 三套 TTS 端点，实时场景很香 | [Pricing](https://cartesia.ai/pricing) / [Bytes API](https://docs.cartesia.ai/api-reference/tts/bytes) / [WS API](https://docs.cartesia.ai/api-reference/tts/tts) |

---

## 国内：明确有免费档或试用额度的 TTS API

| 厂商 | 产品 / API | 免费类型 | 2026-04-26 可用额度 | 接口形态 | 对 Neiroha 的实现建议 | 备注 | 官方 |
|---|---|---|---|---|---|---|---|
| 阿里云百炼 | Qwen-TTS | 试用档 | `输入 100 万 token + 输出 100 万 token`，`180 天` 有效 | 百炼 API / SDK | **大概率 custom adapter** | 免费量对打样够用；偏自然语音合成，不是 OpenAI `/audio/speech` | [Qwen-TTS docs](https://help.aliyun.com/zh/model-studio/qwen-tts/) / [Pricing](https://help.aliyun.com/document_detail/2975508.html) |
| 阿里云百炼 | CosyVoice | 试用档 | `1 万字符`，`90 天` 有效（中国内地部署） | 百炼 API / SDK | **可参考仓库现有 `cosyvoice` 适配思路** | 国际部署官方写了**无免费额度** | [Model billing](https://help.aliyun.com/zh/model-studio/billing-for-model-studio) / [CosyVoice SDK pricing](https://help.aliyun.com/zh/model-studio/cosyvoice-android-sdk) |
| 阿里云百炼 | Sambert 语音合成 | 免费档 | `每主账号每模型每月 3 万字符` | 百炼 API | **新建 custom adapter** | 这是阿里系里最像“持续免费月额度”的一个 | [Model list & billing](https://help.aliyun.com/zh/model-studio/model) |
| 腾讯云 | 语音合成（通用） | 试用档 | `800 万字符`，`3 个月`，`仅支持通用语音合成接口`，一个账号只能领一次 | Cloud API + WebSocket | **新建 custom adapter** | 免费量非常大；长文本接口不在免费包里 | [Free quota](https://cloud.tencent.com/document/product/1073/78325) / [Base API](https://cloud.tencent.com/document/product/1073/37995) / [Realtime API](https://cloud.tencent.com/document/product/1073/94308) |
| 百度智能云 | 语音合成 | 免费档（官方有，但文档未公开精确值） | 官方文档只明确写了：`每个接口均提供一定额度的免费调用量供测试使用`；精确额度以控制台展示为准 | REST / WS / SDK | **新建 custom adapter** | 适合列入候选，但做前先去控制台确认你账号下的真实免费包 | [Speech docs index](https://cloud.baidu.com/doc/SPEECH/index.html) / [TTS product](https://cloud.baidu.com/product/SPEECH/tts.html) / [TTS pricing page](https://cloud.baidu.com/doc/SPEECH/s/Ql9misjot) |
| 火山引擎 | 语音技术 TTS（经典） | 试用档 | `1000 次免费调用`，自开通之日 `3 个月`，免费并发 `2` | HTTP / WebSocket | **新建 custom adapter** | 免费量不大，但官方计费页给得很清楚 | [Pricing](https://www.volcengine.com/docs/6489/381594) / [Getting started](https://www.volcengine.com/docs/6627/105414) |
| 火山引擎 | 豆包语音 | 试用档 | 官方只写“创建应用后可享有一定量免费试用额度”，**具体数值以控制台领取页为准** | HTTP / WebSocket | **新建 custom adapter** | 当前更“现役”的字节语音入口，但公开文档没把试用量写死 | [Billing overview](https://www.volcengine.com/docs/6561/1359369) / [Online TTS API](https://www.volcengine.com/docs/6561/79819) |
| SiliconFlow | OpenAI-compatible TTS | 试用档 | 新用户注册即送 `14 元` 额度；官方 TTS 走 `/audio/speech`；免费模型的限流策略公开，但 TTS 是否有“永久免费模型”未单列 | **OpenAI-compatible** `/v1/audio/speech` | **优先接，最省事** | 对 Neiroha 最友好；先用赠送额度做验证非常合适 | [TTS docs](https://docs.siliconflow.com/en/userguide/capabilities/text-to-speech) / [Billing](https://docs.siliconflow.com/en/faqs/billing-rules) / [Rate limits FAQ](https://docs.siliconflow.com/en/faqs/misc_rate) |

---

## 计划型 / 赠送型：不算严格免费，但你提到要把 `Token Plan / Coding Plan` 算进去

| 厂商 | 计划 | 这算不算“免费” | 2026-04-26 可用额度 | 对 Neiroha 的实现建议 | 备注 | 官方 |
|---|---|---|---|---|---|---|
| MiniMax | Token Plan（旧 `Coding Plan` 已并入 / 延伸） | **不算免费**，但非常值得单列 | Token Plan 月付标准档：`Plus` 含 `4,000 chars / day` TTS，`Max` 含 `11,000 chars / day`；High-Speed 年付档更高 | **新建 custom adapter** | 你提到的 `Token Plan / Coding Plan` 基本就是它；官方文档明确说 Token Plan 是在旧 Coding Plan 基础上扩展到多模态 | [Token Plan overview](https://platform.minimax.io/docs/token-plan/intro) / [Token Plan pricing](https://platform.minimax.io/docs/guides/pricing-token-plan) / [T2A API](https://platform.minimax.io/docs/api-reference/speech-t2a-intro) |
| MiniMax | Pay-as-you-go | 不是免费 | TTS Turbo `US$60 / M chars`；TTS HD `US$100 / M chars` | **新建 custom adapter** | 如果你后面要做“免费档之外的完整实现”，这就是正式计费口径 | [Pay as you go](https://platform.minimax.io/docs/guides/pricing-paygo) / [API overview](https://platform.minimax.io/docs/api-reference/api-overview) |

---

## 我会暂时不优先接的几家

这些不是说不能接，而是**按“免费先试、实现效率优先”**这个标准，我会放后面：

- **OpenAI TTS API**：官方没有公开长期免费 API 档。
- **Resemble AI**：官方现在主打 `Flex` 按量付费，未看到明确免费 API 配额。
- **PlayAI / Play.ht**：官网有免费网页体验，但公开页对“免费 API 配额”写得不够稳，不如前面的厂商清楚。
- **Fish Audio**：官网有 `Free Tier`（`8,000 credits / 月`），但 API 定价页又写 API 是纯 pay-as-you-go；“免费档 credits 能否直接走官方 API”公开文档没有写死，先不把它放进主推荐名单。

---

## 真要一个个实现，建议落地顺序

### 第一批：最省时间

1. **SiliconFlow**
2. **腾讯云 TTS**
3. **阿里 Qwen-TTS**
4. **阿里 CosyVoice**

### 第二批：拿来做质量 / 能力对照

5. **Google Gemini API TTS**
6. **ElevenLabs**
7. **Deepgram**
8. **Cartesia**

### 第三批：补全生态覆盖

9. **Google Cloud TTS**
10. **Amazon Polly**
11. **IBM Watson TTS**
12. **Hume**
13. **百度智能云**
14. **火山引擎 / 豆包语音**
15. **MiniMax Token Plan / PayGo**

---

## 对接层面的一个小提醒

结合仓库里现有文档 [`llm-tts-adapter-guide.md`](./llm-tts-adapter-guide.md) 来看，后面实现时可以先按三类切：

- **最容易复用现有思路**
  - SiliconFlow：最接近现有 `openAiTts`
  - 阿里 CosyVoice：可以参考现有 `cosyvoice` 适配
- **需要单独 REST / WS adapter**
  - 腾讯云、百度、火山、AWS Polly、Google Cloud、Deepgram、Cartesia、Hume、ElevenLabs、IBM
- **计划型 / 专有协议，后补**
  - MiniMax Token Plan / Pay-as-you-go

如果你后面要把这份表继续拆成“逐个 provider 的实现任务单”，最先拆 `SiliconFlow -> 腾讯云 -> 阿里 Qwen-TTS -> 阿里 CosyVoice` 这四个就行，收益最大。
