import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart';

import 'app_providers.dart';

final quickTtsStreamingProvider = StreamProvider.autoDispose
    .family<bool, String>(
      (ref, voiceId) =>
          ref.watch(databaseProvider).watchQuickTtsStreaming(voiceId),
    );
