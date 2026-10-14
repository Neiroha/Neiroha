import 'package:flutter_riverpod/legacy.dart';

/// Currently selected character id shared by the Voice Bank list and inspector.
final selectedCharacterIdProvider = StateProvider<String?>((ref) => null);
