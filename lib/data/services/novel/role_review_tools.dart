import 'dart:convert';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/role_review.dart';
import 'role_review_snapshot.dart';
import 'role_review_merge.dart';
import 'role_analysis_context.dart';

class RoleReviewTools {
  const RoleReviewTools(this.snapshot);
  final RoleReviewSnapshot snapshot;
  static const pronouns = {
    '我',
    '你',
    '他',
    '她',
    '它',
    '吾',
    '我们',
    '你们',
    '他们',
    '她们',
    'i',
    'you',
    'he',
    'she',
  };
  static String string(Map data, String key, int limit, {bool empty = false}) {
    final value = data[key];
    if (value is! String ||
        (!empty && value.trim().isEmpty) ||
        value.length > limit) {
      throw FormatException('Invalid $key.');
    }
    return value.trim();
  }

  void evidence(Map data, RoleReviewSession session) {
    final raw = data['evidence'];
    if (raw is! List || raw.isEmpty || raw.length > 3) {
      throw const FormatException('Missing bounded source evidence.');
    }
    for (final item in raw) {
      if (item is! Map || item.length != 2) {
        throw const FormatException('Invalid evidence anchor.');
      }
      final id = string(item, 'segmentId', 100),
          quote = string(item, 'quote', 160);
      if (quote.length < 2 ||
          !session.visibleIds.contains(id) ||
          !(session.excerpts[id]?.any((text) => text.contains(quote)) ??
              false) ||
          !snapshot.requireSegment(id).segmentText.contains(quote)) {
        throw const FormatException(
          'Evidence must quote text actually read from this chapter.',
        );
      }
    }
  }

  void validateCharacter(Map data, Iterable<RoleReviewProposal> proposals) {
    final name = string(data, 'name', 80);
    final aliases = data['aliases'];
    if (aliases is! List ||
        aliases.length > 8 ||
        aliases.any(
          (a) =>
              a is! String ||
              a.trim().isEmpty ||
              a != a.trim() ||
              a.length > 80 ||
              pronouns.contains(a.toLowerCase()),
        )) {
      throw const FormatException('Invalid character aliases.');
    }
    string(data, 'description', 500, empty: true);
    CharacterIdentityKind.values.byName(string(data, 'identityKind', 20));
    if (pronouns.contains(name.toLowerCase())) {
      throw const FormatException('Pronouns are not character identities.');
    }
    final known = <String>{
      for (final c in snapshot.roles.characters) ...[
        c.name.toLowerCase(),
        ...c.aliases.map((n) => n.toLowerCase()),
      ],
      for (final p in proposals.where(
        (p) => p.action == 'propose_character',
      )) ...[
        (p.data['name'] as String).toLowerCase(),
        ...(p.data['aliases'] as List).cast<String>().map(
          (n) => n.toLowerCase(),
        ),
      ],
    };
    if ([
      name,
      ...aliases.cast<String>(),
    ].any((n) => known.contains(n.toLowerCase()))) {
      throw StateError(
        'Character overlaps an existing identity; inspect it or propose an evidenced merge.',
      );
    }
  }

  RoleReviewSession dispatch(
    RoleReviewSession original,
    List<Map<String, dynamic>> actions,
  ) {
    final session = RoleReviewSession.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    for (final a in actions) {
      if (session.status == 'ready') {
        throw const FormatException('No actions after finish.');
      }
      final name = string(a, 'action', 30);
      Object? result;
      if (['read_context', 'search_text', 'inspect_character'].contains(name)) {
        final cacheKey = jsonEncode(a);
        final cached = session.journal
            .where((j) => j['cacheKey'] == cacheKey)
            .firstOrNull;
        if (cached != null) {
          result = cached['result'];
        } else {
          if (session.reads >= session.budget.maxReads) {
            throw StateError('Local tool-read budget exhausted.');
          }
          session.reads++;
          switch (name) {
            case 'read_context':
              _keys(a, ['segmentId', 'radius']);
              final id = string(a, 'segmentId', 100), radius = a['radius'];
              if (radius is! int || radius < 0 || radius > 2) {
                throw const FormatException('Invalid context radius.');
              }
              snapshot.requireSegment(id);
              final at = snapshot.chapter.indexWhere((s) => s.id == id);
              final rows = snapshot.chapter.sublist(
                (at - radius).clamp(0, snapshot.chapter.length),
                (at + radius + 1).clamp(0, snapshot.chapter.length),
              );
              session.visibleIds.addAll(
                rows
                    .map((s) => s.id)
                    .where((id) => !session.visibleIds.contains(id)),
              );
              for (final row in rows) {
                _remember(
                  session,
                  row.id,
                  RoleAnalysisContext.excerpt(row.segmentText, 450),
                );
              }
              result = rows
                  .map((s) => snapshot.segment(s, limit: 450))
                  .toList();
            case 'search_text':
              _keys(a, ['query']);
              final query = string(a, 'query', 80);
              final rows = snapshot.chapter
                  .where(
                    (s) => s.segmentText.toLowerCase().contains(
                      query.toLowerCase(),
                    ),
                  )
                  .take(5);
              result = [
                for (final s in rows)
                  {
                    'id': s.id,
                    'text': _snippet(s.segmentText, query),
                    'editable': snapshot.editable(s.id),
                  },
              ];
              session.visibleIds.addAll(
                rows
                    .map((s) => s.id)
                    .where((id) => !session.visibleIds.contains(id)),
              );
              for (final row in rows) {
                _remember(session, row.id, _snippet(row.segmentText, query));
              }
            case 'inspect_character':
              _keys(a, ['query']);
              final query = string(a, 'query', 100).toLowerCase();
              final matches = snapshot.roles.characters
                  .where(
                    (c) =>
                        c.id == query ||
                        c.name.toLowerCase().contains(query) ||
                        c.aliases.any((n) => n.toLowerCase().contains(query)),
                  )
                  .take(3);
              result = [
                for (final c in matches)
                  {
                    'id': c.id,
                    'name': c.name,
                    'aliases': c.aliases.take(8).toList(),
                    'description': RoleAnalysisContext.excerpt(
                      c.description,
                      500,
                    ),
                    'identityKind': c.identityKind.name,
                    'references': [
                      for (final s
                          in snapshot.chapter
                              .where(
                                (s) =>
                                    snapshot
                                        .roles
                                        .annotations[s.id]
                                        ?.characterId ==
                                    c.id,
                              )
                              .take(3))
                        snapshot.segment(s, limit: 300),
                    ],
                    'boundVoices': snapshot.roles.bindings
                        .where((b) => b.characterId == c.id)
                        .take(8)
                        .map(
                          (b) => {
                            'chapterId': b.chapterId,
                            'kind': b.kind?.name,
                            'voiceId': b.voiceAssetId,
                          },
                        )
                        .toList(),
                  },
              ];
              for (final c in matches) {
                for (final row
                    in snapshot.chapter
                        .where(
                          (s) =>
                              snapshot.roles.annotations[s.id]?.characterId ==
                              c.id,
                        )
                        .take(3)) {
                  _remember(
                    session,
                    row.id,
                    RoleAnalysisContext.excerpt(row.segmentText, 300),
                  );
                }
                session.visibleIds.addAll(
                  snapshot.chapter
                      .where(
                        (s) =>
                            snapshot.roles.annotations[s.id]?.characterId ==
                            c.id,
                      )
                      .take(3)
                      .map((s) => s.id)
                      .where((id) => !session.visibleIds.contains(id)),
                );
              }
          }
          session.journal.add({
            'action': name,
            'cacheKey': cacheKey,
            'result': result,
          });
        }
      } else if (name == 'finish') {
        _keys(a, ['reason']);
        session.summary = string(a, 'reason', 300);
        session.status = 'ready';
        session.journal.add({'action': name, 'result': session.summary});
      } else {
        final key = string(a, 'key', 40);
        if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]{0,31}$').hasMatch(key) ||
            session.proposals.any((p) => p.key == key)) {
          throw const FormatException('Duplicate or invalid proposal key.');
        }
        if (session.proposals.length >= session.budget.maxProposals) {
          throw StateError('Proposal budget exhausted.');
        }
        string(a, 'reason', 300);
        evidence(a, session);
        final data = Map<String, dynamic>.from(a)
          ..remove('action')
          ..remove('key');
        switch (name) {
          case 'propose_character':
            _keys(a, [
              'key',
              'name',
              'aliases',
              'description',
              'identityKind',
              'reason',
              'evidence',
            ]);
            validateCharacter(data, session.proposals);
            final quotes = (data['evidence'] as List)
                .map((e) => e['quote'] as String)
                .join('\n');
            if ((data['identityKind'] == 'named' &&
                    !quotes.contains(data['name'] as String)) ||
                (data['aliases'] as List).any(
                  (alias) => !quotes.contains(alias as String),
                )) {
              throw const FormatException(
                'Named identities and aliases need literal source evidence.',
              );
            }
          case 'propose_patch':
            _keys(a, [
              'key',
              'segmentId',
              'characterRef',
              'kind',
              'reason',
              'evidence',
            ]);
            final id = string(a, 'segmentId', 100);
            if (!session.targets.contains(id) || !snapshot.editable(id)) {
              throw StateError('Patch is outside the unlocked review targets.');
            }
            if (session.proposals.any(
              (p) => p.action == name && p.data['segmentId'] == id,
            )) {
              throw const FormatException('Duplicate segment proposal.');
            }
            NovelSegmentKind.values.byName(string(a, 'kind', 20));
            final ref = a['characterRef'];
            if (ref != null &&
                session.proposals.any(
                  (p) => p.action == 'propose_merge' && p.data['fromId'] == ref,
                )) {
              throw const FormatException(
                'Patch must reference the surviving merged identity.',
              );
            }
            if (ref != null) {
              if (ref is! String || ref.length > 100) {
                throw const FormatException('Invalid character reference.');
              }
              if (ref.startsWith('new:')) {
                if (!session.proposals.any(
                  (p) =>
                      p.action == 'propose_character' &&
                      p.key == ref.substring(4),
                )) {
                  throw const FormatException('Unknown proposed character.');
                }
              } else {
                snapshot.requireCharacter(ref);
              }
            }
          case 'propose_merge':
            _keys(a, ['key', 'fromId', 'intoId', 'reason', 'evidence']);
            final from = string(a, 'fromId', 100),
                into = string(a, 'intoId', 100);
            final affected = RoleReviewMerge.validate(snapshot, from, into);
            if (session.proposals.any(
              (p) =>
                  p.action == 'propose_patch' && p.data['characterRef'] == from,
            )) {
              throw const FormatException(
                'An existing patch still references the retiring identity.',
              );
            }
            if (session.proposals
                .where((p) => p.action == name)
                .any(
                  (p) => [
                    p.data['fromId'],
                    p.data['intoId'],
                  ].any((id) => id == from || id == into),
                )) {
              throw const FormatException(
                'Overlapping identity merges require separate review.',
              );
            }
            final quoted = (a['evidence'] as List)
                .map((e) => e['quote'] as String)
                .join('\n');
            for (final id in [from, into]) {
              final c = snapshot.requireCharacter(id);
              final named = [c.name, ...c.aliases].any(quoted.contains);
              final linked = (a['evidence'] as List).any(
                (e) =>
                    snapshot.roles.annotations[e['segmentId']]?.characterId ==
                    id,
              );
              if (!named && !linked) {
                throw const FormatException(
                  'Merge evidence must identify both people.',
                );
              }
            }
            data['affectedIds'] = affected.map((a) => a.segmentId).toList();
          default:
            throw const FormatException('Unknown local review action.');
        }
        session.proposals.add(
          RoleReviewProposal(key: key, action: name, data: data),
        );
        session.journal.add({
          'action': name,
          'result': {'key': key, 'status': 'proposed_only'},
        });
      }
      if (session.journal.length > 16) {
        throw StateError('Local action budget exhausted.');
      }
    }
    return session;
  }

  static void _keys(Map a, List<String> keys) {
    if (a.length != keys.length + 1 ||
        a.keys.any((k) => k != 'action' && !keys.contains(k))) {
      throw const FormatException('Unexpected tool arguments.');
    }
  }

  static void _remember(RoleReviewSession s, String id, String text) {
    final excerpts = s.excerpts.putIfAbsent(id, () => []);
    if (!excerpts.contains(text)) excerpts.add(text);
  }

  static String _snippet(String text, String query) {
    final at = text.toLowerCase().indexOf(query.toLowerCase());
    var start = (at - 100).clamp(0, text.length);
    if (start > 0 &&
        text.codeUnitAt(start) >= 0xDC00 &&
        text.codeUnitAt(start) <= 0xDFFF) {
      start--;
    }
    return RoleAnalysisContext.excerpt(text.substring(start), 350);
  }
}
