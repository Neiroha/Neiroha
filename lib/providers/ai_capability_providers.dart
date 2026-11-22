import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart';

import 'app_providers.dart';

/// Capability router over the enabled provider connections. Features ask it
/// for `stt`, `vad`, `vc`… instead of reading provider rows directly.
final aiCapabilityRouterProvider = StreamProvider<CapabilityRouter>(
  (ref) => ref
      .watch(databaseProvider)
      .watchAllProviders()
      .map(CapabilityRouter.fromProviders),
);
