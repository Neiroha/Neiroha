import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:neiroha/data/ai/providers/openai/tts/openai_tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/domain/capabilities/service_endpoint.dart';
import 'package:neiroha/domain/capabilities/task_profile.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

import 'capability_repository.dart';
import 'role_ai_connection.dart';

class RoleAiModel {
  const RoleAiModel(this.capabilities);
  final CapabilityRepository capabilities;

  Future<void> requireForTask(
    db.TtsProvider provider,
    String model,
    TaskProfile? profile,
    TtsCancelToken cancellation,
  ) => requireTools(
    provider,
    model,
    profile?.route ?? ServiceRoute.chatCompletions,
    endpointPath: profile?.endpointPath,
    apiKeyHeader: profile?.apiKeyHeader,
    cancellation: cancellation,
  );

  static CapabilitySupport documented(
    db.TtsProvider provider,
    String model,
    ServiceRoute route,
  ) {
    if (!provider.supportsRoleAi || !isRoleAiRoute(route)) {
      return CapabilitySupport.unsupported;
    }
    if (provider.isOfficialOpenAi) {
      if (model == defaultRoleAiModel) return CapabilitySupport.supported;
      if (OpenAiTtsAdapter.kModels.any((entry) => entry.id == model) ||
          model.startsWith('gpt-realtime-') ||
          model == 'gpt-live-1') {
        return CapabilitySupport.unsupported;
      }
    }
    return CapabilitySupport.unknown;
  }

  Future<CapabilitySupport> support(
    db.TtsProvider provider,
    String model,
    ServiceRoute route,
  ) async {
    final known = documented(provider, model, route);
    if (known == CapabilitySupport.unsupported) return known;
    final saved = await capabilities.load(provider, model, route);
    if (saved.support('text') == CapabilitySupport.unsupported) {
      return CapabilitySupport.unsupported;
    }
    final tools = saved.support(roleAiToolCapability);
    return tools == CapabilitySupport.unknown ? known : tools;
  }

  Future<void> requireTools(
    db.TtsProvider provider,
    String model,
    ServiceRoute route, {
    String? endpointPath,
    String? apiKeyHeader,
    TtsCancelToken? cancellation,
  }) async {
    final available = await support(provider, model, route);
    if (available == CapabilitySupport.supported) return;
    if (available == CapabilitySupport.unknown &&
        await verify(
          provider,
          model,
          route,
          endpointPath: endpointPath,
          apiKeyHeader: apiKeyHeader,
          cancellation: cancellation,
        )) {
      return;
    }
    throw StateError('Choose a text model that supports function calling.');
  }

  /// One bounded request with synthetic input, sent before any script text.
  Future<bool> verify(
    db.TtsProvider provider,
    String model,
    ServiceRoute route, {
    String? endpointPath,
    String? apiKeyHeader,
    TtsCancelToken? cancellation,
  }) async {
    if (documented(provider, model, route) == CapabilitySupport.unsupported) {
      return false;
    }
    const name = 'neiroha_check';
    const prompt = 'Call the neiroha_check function with no arguments.';
    const function = {
      'name': name,
      'description': 'Check function calling support.',
      'parameters': {
        'type': 'object',
        'properties': <String, Object?>{},
        'additionalProperties': false,
      },
    };
    final responses = route == ServiceRoute.responses;
    final header = ServiceEndpoint.validateHeader(
      apiKeyHeader ?? provider.roleAiKeyHeader,
    );
    final path = ServiceEndpoint.validatePath(
      endpointPath ?? (responses ? 'responses' : 'chat/completions'),
    );
    final base = provider.roleAiBaseUrl;
    final dio = Dio(
      BaseOptions(
        baseUrl: base.endsWith('/') ? base : '$base/',
        followRedirects: false,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          if (provider.apiKey.isNotEmpty)
            header: header.toLowerCase() == 'authorization'
                ? 'Bearer ${provider.apiKey}'
                : provider.apiKey,
        },
      ),
    );
    final cancel = CancelToken();
    final remove = cancellation?.onCancel(() => cancel.cancel());
    try {
      final response = await dio.post<dynamic>(
        path,
        cancelToken: cancel,
        data: {
          'model': model,
          if (responses) ...{
            'input': prompt,
            'store': false,
            'max_output_tokens': 256,
            if (provider.isOfficialOpenAi && model.startsWith('gpt-6'))
              'reasoning': {'effort': 'none'},
            'tools': [
              {'type': 'function', ...function},
            ],
            'tool_choice': {'type': 'function', 'name': name},
          } else ...{
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
            (provider.isOfficialOpenAi
                    ? 'max_completion_tokens'
                    : 'max_tokens'):
                256,
            if (provider.isOfficialOpenAi && model.startsWith('gpt-6'))
              'reasoning_effort': 'none',
            'tools': [
              {'type': 'function', 'function': function},
            ],
            'tool_choice': {
              'type': 'function',
              'function': {'name': name},
            },
          },
        },
      );
      cancellation?.throwIfCancelled();
      final data = response.data;
      final choices = data is Map ? data['choices'] : null;
      final first = choices is List && choices.isNotEmpty
          ? choices.first
          : null;
      final message = first is Map ? first['message'] : null;
      final calls = responses && data is Map
          ? data['output']
          : message is Map
          ? message['tool_calls']
          : null;
      final complete = responses
          ? data is Map && data['status'] == 'completed'
          : first is Map &&
                const [
                  null,
                  'stop',
                  'tool_calls',
                ].contains(first['finish_reason']);
      if (!complete ||
          calls is! List ||
          !calls.whereType<Map>().any((call) {
            final target = responses ? call : call['function'];
            return target is Map &&
                call['type'] == (responses ? 'function_call' : 'function') &&
                target['name'] == name &&
                _emptyArguments(target['arguments']);
          })) {
        throw StateError(
          'Function calling check did not return a complete probe call. Retry or choose another model.',
        );
      }
      await _record(provider, model, route, true);
      return true;
    } on DioException catch (error) {
      cancellation?.throwIfCancelled();
      final status = error.response?.statusCode;
      final detail = '${error.response?.data}'.toLowerCase();
      if ({400, 422}.contains(status) &&
          (detail.contains('function') || detail.contains('tools')) &&
          (detail.contains('not support') || detail.contains('unsupported'))) {
        await _record(provider, model, route, false);
        return false;
      }
      throw StateError(
        'Function calling check failed (${status ?? error.type.name}).',
      );
    } finally {
      remove?.call();
      dio.close(force: true);
    }
  }

  static bool _emptyArguments(Object? arguments) {
    if (arguments is! String) return false;
    try {
      final args = jsonDecode(arguments);
      return args is Map && args.isEmpty;
    } on FormatException {
      return false;
    }
  }

  Future<void> _record(
    db.TtsProvider provider,
    String model,
    ServiceRoute route,
    bool valid,
  ) => capabilities.save(
    provider,
    ModelCapability(
      connectionId: capabilities.scope(provider),
      modelId: model,
      route: route,
      availability: ModelAvailability.available,
      facts: {
        roleAiToolCapability: CapabilityEvidence(
          valid ? CapabilitySupport.supported : CapabilitySupport.unsupported,
          CapabilitySource.observed,
          checkedAt: DateTime.now().toUtc(),
        ),
      },
    ),
  );
}
