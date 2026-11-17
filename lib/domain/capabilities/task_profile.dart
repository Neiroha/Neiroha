import 'model_capability.dart';
import 'service_endpoint.dart';

enum ModelTask { analysis, casting, tone, synthesis }

class TaskProfile {
  const TaskProfile({
    required this.task,
    required this.providerId,
    required this.model,
    required this.route,
    this.endpointPath,
    this.apiKeyHeader = 'Authorization',
  });
  final ModelTask task;
  final String providerId;
  final String model;
  final ServiceRoute route;
  final String? endpointPath;
  final String apiKeyHeader;
  void validate() {
    if (providerId.isEmpty || model.trim().isEmpty) {
      throw ArgumentError('Select a connection and model.');
    }
    if (task == ModelTask.synthesis
        ? !{
            ServiceRoute.speech,
            ServiceRoute.realtime,
            ServiceRoute.native,
          }.contains(route)
        : !{
            ServiceRoute.chatCompletions,
            ServiceRoute.responses,
          }.contains(route)) {
      throw ArgumentError('Protocol does not serve this task.');
    }
    if (endpointPath != null) ServiceEndpoint.validatePath(endpointPath!);
    ServiceEndpoint.validateHeader(apiKeyHeader);
    if (route == ServiceRoute.native && endpointPath != null) {
      throw ArgumentError('Native adapters own their endpoint paths.');
    }
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'task': task.name,
    'providerId': providerId,
    'model': model,
    'route': route.name,
    'endpointPath': endpointPath,
    'apiKeyHeader': apiKeyHeader,
  };
  factory TaskProfile.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unknown task profile');
    }
    final result = TaskProfile(
      task: ModelTask.values.byName(json['task'] as String),
      providerId: json['providerId'] as String,
      model: json['model'] as String,
      route: ServiceRoute.values.byName(json['route'] as String),
      endpointPath: json['endpointPath'] as String?,
      apiKeyHeader: json['apiKeyHeader'] as String,
    );
    result.validate();
    return result;
  }
}
