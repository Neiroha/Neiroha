import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/domain/capabilities/service_endpoint.dart';

/// Facts a route declaration may state; other keys are ignored.
const declaredFactKeys = {
  'text',
  'speech',
  'streaming',
  'structuredOutput',
  'functionCalling',
  'audioInput',
  'audioOutput',
  'instructions',
};

/// A voice a self-hosted service ships.
class DeclaredVoice {
  const DeclaredVoice(this.id, {this.name = '', this.languages = const []});
  final String id;
  final String name;
  final List<String> languages;

  String get label => name.isEmpty || name == id ? id : '$name [$id]';

  Map<String, Object?> toJson() => {
    'id': id,
    if (name.isNotEmpty) 'name': name,
    if (languages.isNotEmpty) 'languages': languages,
  };
}

/// One model of a `.well-known/neiroha-capabilities` document.
class DeclaredModel {
  const DeclaredModel({
    required this.id,
    required this.name,
    required this.routes,
    this.languages = const [],
    this.voices = const [],
    this.paths = const {},
    this.streamFormats = const [],
  });
  final String id;
  final String name;

  /// route name → fact → true / false / null (unknown).
  final Map<String, Map<String, bool?>> routes;
  final List<String> languages;
  final List<DeclaredVoice> voices;

  /// Purpose → relative path (`speech` → `audio/speech`), validated.
  final Map<String, String> paths;

  /// Streamed audio encodings (`pcm`, `wav`…), empty when unknown.
  final List<String> streamFormats;
}

/// How the service wants its key, when it states it (v2 `auth`).
class DeclaredAuth {
  const DeclaredAuth({required this.header, this.scheme});
  final String header;
  final String? scheme;
}

/// A validated capability declaration. Version 1 lists models with route
/// facts; version 2 adds voices, languages, streaming formats, interface
/// paths and auth. Whole documents are validated before anything is used.
class CapabilityDeclaration {
  const CapabilityDeclaration({
    required this.version,
    required this.models,
    this.name,
    this.auth,
  });
  final int version;
  final String? name;
  final DeclaredAuth? auth;
  final List<DeclaredModel> models;

  static const maxModels = 5000;
  static const maxVoices = 20000;

  factory CapabilityDeclaration.parse(Object? object) {
    Never bad(String what) =>
        throw FormatException('Invalid capability declaration: $what.');
    if (object is! Map) bad('not an object');
    final version = object['version'];
    if (version != 1 && version != 2) bad('unsupported version');
    final rawModels = object['models'];
    if (rawModels is! List || rawModels.length > maxModels) bad('models');

    List<String> strings(Object? value, String what) {
      if (value == null) return const [];
      if (value is! List || value.any((v) => v is! String || v.isEmpty)) {
        bad(what);
      }
      return [for (final v in value) v as String];
    }

    var voiceCount = 0;
    final seen = <String>{};
    final models = <DeclaredModel>[];
    for (final model in rawModels) {
      if (model is! Map ||
          model['id'] is! String ||
          (model['id'] as String).isEmpty ||
          model['routes'] is! Map ||
          !seen.add(model['id'] as String)) {
        bad('invalid or duplicate model');
      }
      final id = model['id'] as String;
      final routes = <String, Map<String, bool?>>{};
      for (final MapEntry(:key, :value) in (model['routes'] as Map).entries) {
        if (value == null) continue;
        if (key is! String || value is! Map) bad('route features of $id');
        routes[key] = {
          for (final MapEntry(key: fact, value: support) in value.entries)
            if (declaredFactKeys.contains(fact))
              fact as String: switch (support) {
                null => null,
                final bool b => b,
                _ => bad('fact $fact of $id must be bool or null'),
              },
        };
      }
      final voices = <DeclaredVoice>[];
      final voiceIds = <String>{};
      if (version == 2) {
        final raw = model['voices'];
        if (raw != null && raw is! List) bad('voices of $id');
        for (final v in (raw as List?) ?? const []) {
          final voice = switch (v) {
            final String s when s.isNotEmpty => DeclaredVoice(s),
            {'id': final String vid} when vid.isNotEmpty => DeclaredVoice(
              vid,
              name: v['name'] is String ? v['name'] as String : '',
              languages: strings(v['languages'], 'voice languages'),
            ),
            _ => bad('voice of $id'),
          };
          if (!voiceIds.add(voice.id)) bad('duplicate voice ${voice.id}');
          voices.add(voice);
        }
        voiceCount += voices.length;
        if (voiceCount > maxVoices) bad('too many voices');
      }
      final paths = <String, String>{};
      final rawPaths = version == 2 ? model['paths'] : null;
      if (rawPaths != null) {
        if (rawPaths is! Map) bad('paths of $id');
        for (final MapEntry(:key, :value) in rawPaths.entries) {
          if (key is! String || value is! String) bad('path of $id');
          try {
            paths[key] = ServiceEndpoint.validatePath(value);
          } on ArgumentError {
            bad('path $key of $id must stay within the service');
          }
        }
      }
      final streaming = version == 2 ? model['streaming'] : null;
      models.add(
        DeclaredModel(
          id: id,
          name: model['name'] is String ? model['name'] as String : id,
          routes: routes,
          languages: version == 2
              ? strings(model['languages'], 'languages of $id')
              : const [],
          voices: voices,
          paths: paths,
          streamFormats: streaming is Map
              ? strings(streaming['formats'], 'streaming formats of $id')
              : const [],
        ),
      );
    }

    DeclaredAuth? auth;
    final rawAuth = version == 2 ? object['auth'] : null;
    if (rawAuth != null) {
      if (rawAuth is! Map || rawAuth['header'] is! String) bad('auth');
      try {
        auth = DeclaredAuth(
          header: ServiceEndpoint.validateHeader(rawAuth['header'] as String),
          scheme: rawAuth['scheme'] is String
              ? rawAuth['scheme'] as String
              : null,
        );
      } on ArgumentError {
        bad('auth header');
      }
    }
    return CapabilityDeclaration(
      version: version as int,
      name: object['name'] is String ? object['name'] as String : null,
      auth: auth,
      models: models,
    );
  }

  /// Route facts as provider evidence; models without the route are absent.
  static Map<String, CapabilityEvidence>? evidence(
    DeclaredModel model,
    ServiceRoute route,
    DateTime checkedAt,
  ) {
    final facts = model.routes[route.name];
    if (facts == null) return null;
    final streams = model.streamFormats.isNotEmpty;
    return {
      for (final MapEntry(:key, :value) in facts.entries)
        key: CapabilityEvidence(
          value == null
              ? CapabilitySupport.unknown
              : value
              ? CapabilitySupport.supported
              : CapabilitySupport.unsupported,
          CapabilitySource.provider,
          checkedAt: checkedAt,
        ),
      // Declared stream formats imply streaming unless stated otherwise.
      if (streams && facts['streaming'] == null)
        'streaming': CapabilityEvidence(
          CapabilitySupport.supported,
          CapabilitySource.provider,
          checkedAt: checkedAt,
        ),
    };
  }
}
