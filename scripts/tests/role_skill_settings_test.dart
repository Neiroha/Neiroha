import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/services/novel/role_skill_profiles_repository.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/settings/role_skill_settings.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/novel_role_providers.dart';
import 'support/role_review_fixture.dart';
import 'support/role_skill_fixture.dart';

void main() {
  testWidgets(
    'mobile settings can duplicate, edit, activate and restore a role profile',
    (tester) async {
      final f = RoleReviewFixture();
      await tester.runAsync(f.init);
      addTearDown(() => tester.runAsync(f.close));
      final builtin = await tester.runAsync(loadTestRoleSkill);
      final repo = RoleSkillProfilesRepository(
        f.database,
        loadBuiltin: () async => builtin!,
      );
      await tester.binding.setSurfaceSize(const Size(360, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roleSkillProfilesRepositoryProvider.overrideWithValue(repo),
            ttsProvidersStreamProvider.overrideWith(
              (_) => Stream.value([
                f.provider,
                f.provider.copyWith(
                  id: 'tts-only',
                  name: 'CosyVoice',
                  adapterType: 'cosyvoice',
                ),
                f.provider.copyWith(
                  id: 'gemini',
                  name: 'Google AI Studio',
                  adapterType: 'geminiTts',
                ),
              ]),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(child: RoleSkillSettingsCard()),
            ),
          ),
        ),
      );
      Future<void> settleIo() async {
        for (var i = 0; i < 4; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)),
          );
        }
        await tester.pumpAndSettle();
      }

      await settleIo();
      final providerMenu = find.widgetWithText(
        DropdownButtonFormField<String>,
        '使用当前入口选择的连接',
      );
      await tester.ensureVisible(providerMenu);
      await tester.tap(providerMenu);
      await tester.pumpAndSettle();
      expect(find.text('Google AI Studio'), findsOneWidget);
      expect(find.text('CosyVoice'), findsNothing);
      await tester.tap(find.text('使用当前入口选择的连接').last);
      await tester.pumpAndSettle();
      final clone = find.text('复制为新配置');
      await tester.ensureVisible(clone);
      await tester.tap(clone);
      await tester.pumpAndSettle();
      final prompt = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '阶段提示词',
      );
      await tester.ensureVisible(prompt);
      await tester.enterText(prompt, '仅按原文明确证据分角，不改写。');
      final save = find.text('保存并启用配置');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await settleIo();
      final saved = await tester.runAsync(repo.load);
      expect(saved!.profiles, hasLength(2));
      expect(saved.active.id, isNot('default'));
      expect(saved.active.prompts['planner'], '仅按原文明确证据分角，不改写。');
      final restore = find.text('一键还原当前配置');
      await tester.ensureVisible(restore);
      await tester.tap(restore);
      await settleIo();
      expect((await tester.runAsync(repo.load))!.active.prompts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
