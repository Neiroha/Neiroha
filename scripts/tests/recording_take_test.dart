import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_platform_interface/record_platform_interface.dart';
import 'package:neiroha/data/services/recording/recording_backend.dart';
import 'package:neiroha/data/services/recording/recording_take.dart';

class _Backend implements RecordingBackend {
  StreamController<Uint8List>? controller;
  bool disposed = false;
  @override
  bool get supported => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<List<InputDevice>> devices() async => [];
  @override
  Future<Stream<Uint8List>> start(InputDevice? device) async {
    controller = StreamController<Uint8List>();
    return controller!.stream;
  }

  @override
  Future<void> stop() async {
    if (controller != null && !controller!.isClosed) await controller!.close();
  }

  @override
  Future<void> dispose() async => disposed = true;
}

class _DelayedBackend extends _Backend {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<Stream<Uint8List>> start(InputDevice? device) async {
    controller = StreamController<Uint8List>.broadcast();
    started.complete();
    await release.future;
    return controller!.stream;
  }
}

void main() {
  late Directory directory;
  late _Backend backend;
  late RecordingTake take;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('neiroha_record_');
    backend = _Backend();
    take = RecordingTake(backend, onLevel: (_) {});
  });
  tearDown(() async {
    await take.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'recording commits complete 48 kHz WAV at odd chunk boundaries',
    () async {
      final path = '${directory.path}/参考 录音.wav';
      await take.start(path, null);
      backend.controller!.add(Uint8List.fromList([1]));
      backend.controller!.add(Uint8List.fromList([0, 2, 0]));
      expect(File(path).existsSync(), isFalse);
      expect(await take.stop(keepFile: true), path);
      final bytes = await File(path).readAsBytes();
      expect(bytes.sublist(44), [1, 0, 2, 0]);
      expect(ByteData.sublistView(bytes).getUint32(24, Endian.little), 48000);
      expect(
        directory.listSync().where((f) => f.path.endsWith('.partial')),
        isEmpty,
      );
    },
  );

  test('cancel discards the owned partial recording', () async {
    await take.start('${directory.path}/cancel.wav', null);
    backend.controller!.add(Uint8List.fromList([1, 0]));
    expect(await take.stop(keepFile: false), isNull);
    expect(directory.listSync(), isEmpty);
  });

  test(
    'disposing while native start is pending cleans the partial file',
    () async {
      final delayed = _DelayedBackend();
      await take.dispose();
      backend = delayed;
      take = RecordingTake(delayed, onLevel: (_) {});
      final starting = take.start('${directory.path}/race.wav', null);
      final assertion = expectLater(starting, throwsStateError);
      await delayed.started.future;
      await take.dispose();
      delayed.release.complete();
      await assertion;
      expect(directory.listSync(), isEmpty);
    },
  );

  for (final bytes in [
    <int>[],
    [0, 0],
    [1],
  ]) {
    test(
      'empty, silent or truncated recording is not committed: $bytes',
      () async {
        await take.start('${directory.path}/invalid.wav', null);
        backend.controller!.add(Uint8List.fromList(bytes));
        await expectLater(
          take.stop(keepFile: true),
          throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
        );
        expect(directory.listSync(), isEmpty);
      },
    );
  }
}
