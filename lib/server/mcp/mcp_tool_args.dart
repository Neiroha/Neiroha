part of 'neiroha_mcp_tools.dart';

// Schema builders and argument readers.

const _audioExts = {'.wav', '.mp3', '.flac', '.ogg', '.m4a', '.aac', '.opus'};

String _codecForExt(String ext) => switch (ext) {
  '.mp3' => 'libmp3lame',
  '.flac' => 'flac',
  '.m4a' || '.aac' => 'aac',
  '.ogg' || '.opus' => 'libopus',
  _ => 'pcm_s16le',
};

Map<String, dynamic> _obj(
  Map<String, Map<String, dynamic>> props, {
  List<String> required = const [],
}) => {
  'type': 'object',
  'properties': props,
  if (required.isNotEmpty) 'required': required,
};

Map<String, dynamic> _str(String d, {List<String>? enumValues}) => {
  'type': 'string',
  'description': d,
  'enum': ?enumValues,
};

Map<String, dynamic> _int(String d) => {'type': 'integer', 'description': d};

Map<String, dynamic> _num(String d) => {'type': 'number', 'description': d};

Map<String, dynamic> _bool(String d) => {'type': 'boolean', 'description': d};

Map<String, dynamic> _arr(Map<String, dynamic> items) => {
  'type': 'array',
  'items': items,
};

String _req(Map<String, dynamic> a, String k) {
  final v = a[k];
  if (v is String && v.trim().isNotEmpty) return v.trim();
  throw McpToolError('Missing required argument "$k"');
}

/// Trimmed non-empty string, else null.
String? _opt(Map<String, dynamic> a, String k) {
  final v = a[k];
  if (v is String && v.trim().isNotEmpty) return v.trim();
  return null;
}

/// Raw string (may be empty), else null.
String? _raw(Map<String, dynamic> a, String k) {
  final v = a[k];
  return v is String ? v : null;
}

bool? _bool0(Map<String, dynamic> a, String k) {
  final v = a[k];
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  return null;
}

int? _int0(Map<String, dynamic> a, String k) {
  final v = a[k];
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _num0(Map<String, dynamic> a, String k) {
  final v = a[k];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

List<String> _strList(Map<String, dynamic> a, String k) {
  final v = a[k];
  if (v is List) {
    return v.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
  }
  if (v is String && v.trim().isNotEmpty) return [v.trim()];
  return const [];
}
