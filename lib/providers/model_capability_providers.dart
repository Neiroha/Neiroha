import 'package:neiroha/data/services/capabilities/provider_model_inventory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/services/capabilities/capability_repository.dart';
import 'package:neiroha/data/services/capabilities/model_discovery_service.dart';
import 'app_providers.dart';

final capabilityRepositoryProvider = Provider(
  (ref) => CapabilityRepository(ref.watch(databaseProvider)),
);
final modelDiscoveryServiceProvider = Provider(
  (ref) => ModelDiscoveryService(
    ref.watch(databaseProvider),
    ref.watch(capabilityRepositoryProvider),
  ),
);

final providerModelInventoryProvider = Provider(
  (ref) => ProviderModelInventory(
    ref.watch(databaseProvider),
    ref.watch(modelDiscoveryServiceProvider),
  ),
);
