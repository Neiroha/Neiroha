import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/role_scene_state.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/novel_roles/scene_summary.dart';

void main() {
  testWidgets('scene plan is reviewable in a narrow mobile layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: NovelRoleSceneSummary(
              scene: RoleSceneState(
                firstPersonId: 'narrator',
                presentCharacterIds: ['narrator', 'storyteller'],
                nestedNarratorIds: ['storyteller'],
                evidence: '由作品正文中的自我介绍与转述提示推断，仍需核对。',
              ),
              roles: NovelRoleSnapshot(
                characters: [
                  StoryCharacter(id: 'narrator', projectId: 'book', name: '唐禾'),
                  StoryCharacter(
                    id: 'storyteller',
                    projectId: 'book',
                    name: '陈叔',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('第一人称叙述者：唐禾'), findsOneWidget);
    expect(find.text('嵌套讲述者：陈叔'), findsOneWidget);
    expect(find.textContaining('填写反馈'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
