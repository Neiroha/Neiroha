import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/role_scene_state.dart';

void main() {
  const roles = NovelRoleSnapshot(
    characters: [
      StoryCharacter(
        id: 'stable',
        projectId: 'book',
        name: '林舟',
        aliases: ['小林'],
      ),
    ],
  );
  Map<String, Object?> plan() => {
    'firstPersonName': '小林',
    'presentCharacterNames': ['林舟'],
    'nestedNarratorNames': ['小林'],
    'messageChannels': ['spoken', 'chat'],
    'evidence': 'The chapter names the narrator and quoted storyteller.',
  };
  test(
    'scene identities persist as stable IDs rather than names or pronouns',
    () {
      final scene = RoleSceneState.fromPlan(plan(), roles);
      expect(scene.firstPersonId, 'stable');
      expect(RoleSceneState.fromJson(scene.toJson()).nestedNarratorIds, [
        'stable',
      ]);
      expect(
        scene.forRoster(const NovelRoleSnapshot()).values,
        isNot(contains('stable')),
      );
      expect(scene.forRoster(roles)['presentCharacterIds'], ['stable']);
    },
  );
  test('unknown identities and unsupported channels are rejected', () {
    expect(
      () =>
          RoleSceneState.fromPlan({...plan(), 'firstPersonName': '陌生人'}, roles),
      throwsFormatException,
    );
    expect(
      () => RoleSceneState.fromPlan({
        ...plan(),
        'messageChannels': ['execute'],
      }, roles),
      throwsFormatException,
    );
  });
}
