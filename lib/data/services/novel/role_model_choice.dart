import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/novel/role_skill_profile.dart';

/// [profile] with a concrete connection and model. A profile without a
/// connection follows the default LLM (AI services → default models); with
/// no LLM available it is returned unchanged.
RoleSkillProfile effectiveRoleProfile(
  RoleSkillProfile profile,
  CapabilityRouter? router,
) {
  if (profile.providerId != null || router == null) return profile;
  final routed = router.resolve<CapabilityModel>(AiCapability.llm);
  if (routed == null) return profile;
  return RoleSkillProfile(
    id: profile.id,
    name: profile.name,
    model: routed.model.descriptor.id,
    providerId: routed.connection.id,
    prompts: profile.prompts,
  );
}
