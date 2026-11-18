import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/adapters/llm_chat_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/text_role_analysis_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/novel/dubbing_intent.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/role_skill_profile.dart';
import 'package:neiroha/domain/novel/text_role_plan.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/phase_tts/role_assignment_dialog.dart';

import 'support/role_skill_fixture.dart';

const _intro = '陈叔讲完后，房间安静了。\n';
const _quote = '“别回头👋。”';
const _provider = db.TtsProvider(
  id: 'fake',
  name: '测试服务',
  adapterType: 'openaiTts',
  baseUrl: 'http://localhost',
  apiKey: '',
  defaultModelName: 'fake',
  enabled: true,
  position: 0,
  maxConcurrency: 1,
);
const _voice = db.VoiceAsset(
  id: 'test-voice',
  name: '测试音色',
  providerId: 'fake',
  taskMode: 'presetVoice',
  speed: 1,
  enabled: true,
  loudnessOffsetDb: 0,
);

class _Analysis extends TextRoleAnalysisService {
  _Analysis() : super(TtsQueueService.instance, loadSkill: loadTestRoleSkill);
  final intents = <String>[];
  final tokens = <TtsCancelToken>[];
  Completer<TextRolePlan>? pending;

  @override
  Future<TextRolePlan> analyze({
    required String text,
    required String intent,
    required db.TtsProvider provider,
    required String model,
    required TtsCancelToken cancellation,
    LlmChatAdapter? client,
    void Function(RoleAnalysisProgress)? onProgress,
  }) async {
    expect(text, _intro + _quote);
    intents.add(intent);
    tokens.add(cancellation);
    onProgress?.call(
      const RoleAnalysisProgress(
        stage: 'labelChunk',
        processed: 1,
        total: 2,
        calls: 2,
      ),
    );
    final request = pending = Completer<TextRolePlan>();
    final remove = cancellation.onCancel(
      () => request.completeError(const TtsCancelledException()),
    );
    try {
      return await request.future;
    } finally {
      remove();
    }
  }

  void finish() {
    pending!.complete(
      TextRolePlan(
        text: _intro + _quote,
        skillDigest: 'test',
        calls: 2,
        characters: const [
          StoryCharacter(id: 'chen', projectId: '', name: '陈叔'),
        ],
        units: [
          TextRoleUnit(
            text: _intro,
            start: 0,
            end: _intro.length,
            kind: NovelSegmentKind.narrator,
            review: NovelReviewState.inferred,
            reason: '场景叙述',
          ),
          TextRoleUnit(
            text: _quote,
            start: _intro.length,
            end: (_intro + _quote).length,
            kind: NovelSegmentKind.dialogue,
            review: NovelReviewState.conflict,
            reason: '引语归属待核对',
          ),
        ],
      ),
    );
  }
}

Future<void> _open(
  WidgetTester tester,
  Size size,
  _Analysis analysis,
  ValueChanged<RoleAssignmentSelection?> onResult, {
  Locale locale = const Locale('zh'),
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onResult(
              await showDialog<RoleAssignmentSelection>(
                context: context,
                builder: (_) => TextRoleAssignmentDialog(
                  text: _intro + _quote,
                  voices: const [_voice],
                  providers: const [_provider],
                  config: const RoleSkillProfile(
                    id: 'test',
                    name: 'Test',
                    model: 'fake',
                  ),
                  queue: TtsQueueService.instance,
                  loadSkill: loadTestRoleSkill,
                  existingSegments: 2,
                  analysisService: analysis,
                ),
              ),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('review remains usable across window sizes with large text', (
    tester,
  ) async {
    final analysis = _Analysis();
    await _open(
      tester,
      const Size(1440, 900),
      analysis,
      (_) {},
      locale: const Locale('en'),
      scale: 1.5,
    );
    final l = AppLocalizations.of(tester.element(find.byType(AlertDialog)));
    final compactApply = find.byTooltip(l.phaseRoleApply);
    await tester.tap(find.text(l.phaseRoleAnalyze));
    await tester.pumpAndSettle();
    analysis.finish();
    await tester.pumpAndSettle();
    for (final size in [
      const Size(1440, 900),
      const Size(1024, 768),
      const Size(768, 1024),
      const Size(640, 360),
      const Size(320, 568),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
      expect(
        find.text(l.phaseRoleApply).hitTestable().evaluate().isEmpty
            ? compactApply.hitTestable()
            : find.text(l.phaseRoleApply).hitTestable(),
        findsOneWidget,
        reason: '$size',
      );
      expect(
        tester.getSize(find.byType(CustomScrollView)).height,
        greaterThan(100),
        reason: '$size',
      );
    }
    final search = find.byType(TextFormField);
    await tester.ensureVisible(search);
    await tester.enterText(search, '陈叔');
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(640, 360);
    tester.view.viewInsets = const FakeViewPadding(bottom: 205);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(CustomScrollView)).height,
      greaterThan(56),
    );
    await tester.ensureVisible(search);
    await tester.pumpAndSettle();
    expect(search.hitTestable(), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '陈叔',
    );
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.tap(compactApply);
    await tester.pumpAndSettle();
    expect(find.text(l.phaseRoleReplaceExisting(2)), findsOneWidget);
    expect(find.text(l.uiApply).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow review edits exact source and applies a new role with voice',
    (tester) async {
      final analysis = _Analysis();
      RoleAssignmentSelection? selection;
      await _open(tester, const Size(360, 640), analysis, (v) => selection = v);
      await tester.tap(find.text('广播剧演绎'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '把房间里的声音分开。');
      await tester.tap(find.text('分析并预览'));
      await tester.pumpAndSettle();
      expect(
        analysis.intents.single,
        dubbingIntent(DubbingMode.dramatized, '把房间里的声音分开。'),
      );
      expect(find.text('已处理 1/2 段 · 已发起 2 次调用'), findsOneWidget);
      analysis.finish();
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '不存在的人物');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('没有符合条件的片段。'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pumpAndSettle();
      final uncertain = find.widgetWithText(FilterChip, '待核对');
      await tester.tap(uncertain);
      await tester.pumpAndSettle();
      expect(find.text(_intro.trim()), findsNothing);
      await tester.tap(find.byTooltip('调整片段归属'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看前后文'));
      await tester.pumpAndSettle();
      expect(find.text(_intro.trim()), findsOneWidget);
      expect(find.textContaining('AI 原始依据'), findsOneWidget);
      final character = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(character);
      await tester.tap(character);
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增人物').last);
      await tester.pumpAndSettle();
      final name = find.byType(TextFormField).last;
      tester.view.viewInsets = const FakeViewPadding(bottom: 310);
      await tester.pumpAndSettle();
      await tester.ensureVisible(name);
      await tester.pumpAndSettle();
      expect(name.hitTestable(), findsOneWidget);
      await tester.enterText(name, '门外人');
      await tester.tap(find.text('保存'));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('没有符合条件的片段。'), findsOneWidget);
      await tester.tap(uncertain);
      await tester.pumpAndSettle();
      expect(find.textContaining('已手动调整'), findsOneWidget);
      expect(find.textContaining('门外人'), findsOneWidget);
      final quoteEdit = find.byTooltip('调整片段归属').last;
      await tester.tap(quoteEdit);
      await tester.pumpAndSettle();
      await tester.tap(find.text('还原 AI 建议'));
      await tester.pumpAndSettle();
      expect(find.textContaining('已手动调整'), findsNothing);
      await tester.tap(quoteEdit);
      await tester.pumpAndSettle();
      await tester.tap(character);
      await tester.pumpAndSettle();
      await tester.tap(find.text('门外人').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('角色音色'));
      await tester.pumpAndSettle();
      final voice = find.byKey(const ValueKey('voice-@narrator'));
      expect(voice, findsOneWidget);
      final addedVoice = find.widgetWithText(
        DropdownButtonFormField<String>,
        '门外人 · 1 句',
      );
      await tester.tap(addedVoice);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_voice.name).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('应用分角与音色'));
      await tester.pumpAndSettle();
      expect(find.textContaining('将替换现有的 2 个片段'), findsOneWidget);
      expect(selection, isNull);
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();

      final result = selection!;
      result.plan.validate();
      expect(result.plan.units.map((u) => u.text).join(), _intro + _quote);
      expect(result.plan.units.last.start, _intro.length);
      expect(result.plan.units.last.manuallyEdited, isTrue);
      expect(
        result.plan.units.last.characterId,
        result.plan.characters.last.id,
      );
      expect(result.plan.characters.last.name, '门外人');
      expect(result.voices[result.plan.characters.last.id], _voice.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop analysis can stop and retry with a different intent', (
    tester,
  ) async {
    final analysis = _Analysis();
    await _open(tester, const Size(1100, 760), analysis, (_) {});
    await tester.tap(find.text('讲述者朗读'));
    await tester.tap(find.text('分析并预览'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('停止分析'));
    await tester.pumpAndSettle();
    expect(analysis.tokens.single.isCancelled, isTrue);
    expect(find.text('分析已停止。可以调整后再试。'), findsOneWidget);
    await tester.tap(find.text('台本与聊天'));
    await tester.tap(find.text('分析并预览'));
    await tester.pumpAndSettle();
    expect(analysis.intents, [
      dubbingIntent(DubbingMode.storyteller, ''),
      dubbingIntent(DubbingMode.script, ''),
    ]);
    expect(analysis.tokens.last.isCancelled, isFalse);
    analysis.finish();
    await tester.pumpAndSettle();

    await tester.tap(find.text('调整配音意图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回已有预览'));
    await tester.pumpAndSettle();
    expect(find.text('审阅角色归属'), findsOneWidget);
    expect(analysis.intents, hasLength(2));
    expect(tester.takeException(), isNull);
  });
}
