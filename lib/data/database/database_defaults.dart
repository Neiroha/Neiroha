import 'package:drift/drift.dart';
import 'package:neiroha/data/ai/providers/openai/tts/openai_tts_adapter.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';

import 'app_database.dart';
import 'migrations/schema_editor.dart';
import 'migrations/v030.dart';
import 'migrations/v032.dart';

/// Seeded by [upgradeToV32].
const _openAiOfficial = 'default-openai-official';

extension DatabaseDefaults on AppDatabase {
  /// Populate the database with built-in providers and starter data so new
  /// users can immediately understand the workflow.
  Future<void> seedDefaults() async {
    final now = DateTime.now();

    // ── Default providers (disabled — user activates after filling in URL) ──
    const providerOpenai = 'default-openai-tts';
    const providerChat = 'default-chat-tts';
    const providerCosyVoice = 'default-cosyvoice';

    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerOpenai),
        name: const Value('OpenAI Compatible'),
        adapterType: const Value('openaiCompatible'),
        baseUrl: const Value('http://localhost:8880/v1'),
        defaultModelName: const Value('tts-1'),
        enabled: const Value(false),
        position: const Value(0),
      ),
    );
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerChat),
        name: const Value('Xiaomi MiMo'),
        adapterType: const Value('chatCompletionsTts'),
        baseUrl: const Value('https://api.xiaomimimo.com/v1'),
        defaultModelName: Value(AdapterType.chatCompletionsTts.defaultModel),
        enabled: const Value(false),
        position: const Value(1),
      ),
    );
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerCosyVoice),
        name: const Value('CosyVoice3 (Local)'),
        adapterType: const Value('cosyvoice'),
        baseUrl: const Value('http://127.0.0.1:9880'),
        defaultModelName: const Value('default'),
        enabled: const Value(false),
        position: const Value(2),
      ),
    );

    const providerVoxCpm2 = 'default-voxcpm2-native';
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerVoxCpm2),
        name: const Value('VoxCPM2 (Local)'),
        adapterType: const Value('voxcpm2Native'),
        baseUrl: const Value('http://127.0.0.1:8000'),
        defaultModelName: const Value('default'),
        enabled: const Value(false),
        position: const Value(3),
      ),
    );

    const providerGptSovits = 'default-gpt-sovits';
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerGptSovits),
        name: const Value('GPT-SoVITS V2 Pro (Local)'),
        adapterType: const Value('gptSovits'),
        baseUrl: const Value('http://127.0.0.1:9880'),
        defaultModelName: const Value('default'),
        enabled: const Value(false),
        position: const Value(4),
      ),
    );

    const providerAzure = 'default-azure-tts';
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerAzure),
        name: const Value('Azure Speech'),
        adapterType: const Value('azureTts'),
        baseUrl: const Value('https://eastus.tts.speech.microsoft.com'),
        defaultModelName: const Value(''),
        enabled: const Value(false),
        position: const Value(5),
      ),
    );

    final platformCapabilities = PlatformCapabilities.current();
    final systemTtsProviderName = platformCapabilities.systemTtsProviderName;
    if (systemTtsProviderName != null) {
      const providerSystem = 'default-system-tts';
      await into(ttsProviders).insert(
        TtsProvidersCompanion(
          id: const Value(providerSystem),
          name: Value(systemTtsProviderName),
          adapterType: const Value('systemTts'),
          baseUrl: const Value(''),
          defaultModelName: const Value(''),
          enabled: const Value(false),
          position: const Value(6),
        ),
      );
    }

    const providerGemini = 'default-gemini-tts';
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerGemini),
        name: const Value('Google AI Studio'),
        adapterType: const Value('geminiTts'),
        baseUrl: const Value('https://generativelanguage.googleapis.com'),
        defaultModelName: const Value('gemini-3.8-flash-tts'),
        enabled: const Value(false),
        position: const Value(7),
      ),
    );

    await upgradeToV30(SchemaEditor(this));
    await upgradeToV32(SchemaEditor(this));

    // Official OpenAI heads the list: one key covers speech, chat, Realtime
    // and transcription, so a new install can try every page with it.
    await customStatement(
      "UPDATE tts_providers SET position = CASE "
      "WHEN id = '$_openAiOfficial' THEN 0 ELSE position + 1 END",
    );

    // ── Default voice character: OpenAI's default model and voice ──
    const defaultCharId = 'default-character';
    await into(voiceAssets).insert(
      VoiceAssetsCompanion(
        id: const Value(defaultCharId),
        name: const Value('Default Voice'),
        description: const Value('Built-in starter character'),
        providerId: const Value(_openAiOfficial),
        modelName: const Value(OpenAiTtsAdapter.defaultModel),
        taskMode: const Value('presetVoice'),
        presetVoiceName: const Value('marin'),
        enabled: const Value(true),
      ),
    );

    // ── Default voice bank (activated) ──
    const defaultBankId = 'default-bank';
    await into(voiceBanks).insert(
      VoiceBanksCompanion(
        id: const Value(defaultBankId),
        name: const Value('Default Bank'),
        description: const Value('Starter voice bank'),
        isActive: const Value(true),
        createdAt: Value(now),
      ),
    );
    await into(voiceBankMembers).insert(
      VoiceBankMembersCompanion(
        id: const Value('default-bank-member'),
        bankId: const Value(defaultBankId),
        voiceAssetId: const Value(defaultCharId),
      ),
    );

    // ── Default Dialog TTS project ──
    await into(dialogTtsProjects).insert(
      DialogTtsProjectsCompanion(
        id: const Value('default-dialog-project'),
        name: const Value('Sample Dialog'),
        bankId: const Value(defaultBankId),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // ── Default Phase TTS project ──
    await into(phaseTtsProjects).insert(
      PhaseTtsProjectsCompanion(
        id: const Value('default-phase-project'),
        name: const Value('Sample Narration'),
        bankId: const Value(defaultBankId),
        scriptText: const Value(
          'Enter your script here.\n\nSeparate paragraphs with blank lines.\nEach paragraph becomes a segment.',
        ),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }
}
