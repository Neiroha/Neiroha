import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Currently selected character id shared by the Voice Bank list and inspector.
final selectedCharacterIdProvider = StateProvider<String?>((ref) => null);
