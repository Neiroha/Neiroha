import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';

void main() {
  test('NavTab.fromName round-trips enum names and rejects unknown values', () {
    for (final tab in NavTab.values) {
      expect(NavTab.fromName(tab.name), tab);
    }

    expect(NavTab.fromName(null), isNull);
    expect(NavTab.fromName('Voice Bank'), isNull);
    expect(NavTab.fromName('voice_bank'), isNull);
  });

  test('startup last value parsing is trimmed and case-insensitive', () {
    expect(AppNavigationSettings.isLastStartupValue('last'), isTrue);
    expect(AppNavigationSettings.isLastStartupValue(' LAST '), isTrue);
    expect(AppNavigationSettings.isLastStartupValue('voiceBank'), isFalse);
    expect(AppNavigationSettings.isLastStartupValue(null), isFalse);
  });

  test('app behavior bool parsing accepts explicit true variants only', () {
    expect(AppBehaviorSettings.parseBool('true', defaultValue: false), isTrue);
    expect(AppBehaviorSettings.parseBool('1', defaultValue: false), isTrue);
    expect(AppBehaviorSettings.parseBool('YES', defaultValue: false), isTrue);

    expect(AppBehaviorSettings.parseBool('false', defaultValue: true), isFalse);
    expect(AppBehaviorSettings.parseBool('0', defaultValue: true), isFalse);
    expect(AppBehaviorSettings.parseBool('', defaultValue: true), isTrue);
    expect(AppBehaviorSettings.parseBool(null, defaultValue: false), isFalse);
  });
}
