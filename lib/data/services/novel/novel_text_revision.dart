import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Existing normalized segment text is canonical. Offsets, when used by the
/// editor, are UTF-16 code units; AI labels always target the stable segment ID.
String novelTextRevision(String text) =>
    sha256.convert(utf8.encode(text)).toString();
