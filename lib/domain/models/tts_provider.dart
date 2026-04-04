import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:q_vox_lab/domain/enums/adapter_type.dart';

part 'tts_provider.freezed.dart';
part 'tts_provider.g.dart';

@freezed
class TtsProvider with _$TtsProvider {
  const factory TtsProvider({
    required String id,
    required String name,
    required AdapterType adapterType,
    required String baseUrl,
    @Default('') String apiKey,
    @Default(true) bool enabled,
  }) = _TtsProvider;

  factory TtsProvider.fromJson(Map<String, dynamic> json) =>
      _$TtsProviderFromJson(json);
}
