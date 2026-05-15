import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';

extension NavTabLocalization on NavTab {
  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      NavTab.novelReader => l10n.navNovelReader,
      NavTab.dialogTts => l10n.navDialogTts,
      NavTab.phaseTts => l10n.navPhaseTts,
      NavTab.videoDub => l10n.navVideoDub,
      NavTab.voiceAssets => l10n.navVoiceAssets,
      NavTab.voiceBank => l10n.navVoiceBank,
      NavTab.providers => l10n.navProviders,
      NavTab.settings => l10n.navSettings,
    };
  }
}

extension SettingsSectionLocalization on SettingsSection {
  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      SettingsSection.general => l10n.settingsGeneral,
      SettingsSection.tasks => l10n.settingsTasks,
      SettingsSection.api => l10n.settingsApi,
      SettingsSection.storage => l10n.settingsStorage,
      SettingsSection.media => l10n.settingsMedia,
      SettingsSection.about => l10n.settingsAbout,
    };
  }

  String localizedDescription(AppLocalizations l10n) {
    return switch (this) {
      SettingsSection.general => l10n.settingsGeneralDescription,
      SettingsSection.tasks => l10n.settingsTasksDescription,
      SettingsSection.api => l10n.settingsApiDescription,
      SettingsSection.storage => l10n.settingsStorageDescription,
      SettingsSection.media => l10n.settingsMediaDescription,
      SettingsSection.about => l10n.settingsAboutDescription,
    };
  }
}
