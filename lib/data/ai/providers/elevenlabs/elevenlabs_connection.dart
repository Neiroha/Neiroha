import 'package:dio/dio.dart';
import 'package:neiroha/data/ai/providers/elevenlabs/stt/elevenlabs_scribe.dart';
import 'package:neiroha/data/ai/providers/elevenlabs/vc/elevenlabs_speech_to_speech.dart';
import 'package:neiroha/data/ai/providers/common/adapter_backed_connection.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/media/audio_input.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';

const elevenLabsBaseUrl = 'https://api.elevenlabs.io';

class ElevenLabsConnection extends AdapterBackedConnection {
  ElevenLabsConnection(super.plugin, super.config);

  Dio get dio {
    final raw = config.baseUrl.trim().isEmpty
        ? elevenLabsBaseUrl
        : config.baseUrl.trim();
    return Dio(
      BaseOptions(
        baseUrl: raw.endsWith('/') ? raw : '$raw/',
        followRedirects: false,
        receiveTimeout: const Duration(minutes: 5),
        headers: {if (config.apiKey.isNotEmpty) 'xi-api-key': config.apiKey},
      ),
    );
  }

  @override
  AiProtocol? manualProtocol(AiCapability cap, String modelId) =>
      cap == AiCapability.stt || cap == AiCapability.vc
      ? AiProtocol.elevenLabs
      : super.manualProtocol(cap, modelId);

  @override
  CapabilityModel? open(AiCapability cap, String modelId) {
    final descriptor = describe(cap, modelId);
    if (descriptor == null) return null;
    return switch (cap) {
      AiCapability.stt => ElevenLabsScribe(descriptor, this),
      AiCapability.vc => ElevenLabsSpeechToSpeech(descriptor, this),
      _ => super.open(cap, modelId),
    };
  }
}

MultipartFile elevenLabsAudioFile(AudioInput audio) => MultipartFile.fromBytes(
  audio.bytes,
  filename: audio.fileName,
  contentType: DioMediaType.parse(audio.contentType),
);
