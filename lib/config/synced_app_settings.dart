import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/cubit/generator_profiles_cubit.dart';
import 'package:keevault/logging/logger.dart';
import 'package:keevault/model/password_generator_profile.dart';

class SyncedAppSettings {
  static KeeVaultEmbeddedConfig export(KeeVaultEmbeddedConfig embeddedConf) {
    final newConfig =
        embeddedConf.vault ?? <String, dynamic>{'prefs': <String, dynamic>{}, 'updatedAt': <String, dynamic>{}};
    newConfig['prefs']['generatorPresets'] = PasswordGeneratorProfileSettings.fromStorage().toMap();
    if (newConfig['updatedAt'] is! Map<String, dynamic>) {
      newConfig['updatedAt'] = <String, dynamic>{};
    }
    newConfig['updatedAt']['generatorPresets'] = DateTime.now().toUtc().millisecondsSinceEpoch;

    return embeddedConf.copyWith(vault: newConfig);
  }

  static Future<void> import(GeneratorProfilesCubit cubit, KeeVaultEmbeddedConfig embeddedConfig) async {
    final embedded = embeddedConfig.vault?['prefs']?['generatorPresets'];
    final int? sourceUpdatedAt = embeddedConfig.vault?['updatedAt']?['generatorPresets'];
    final int ourUpdatedAt = Settings.getValue<int>('embeddedConfigUpdatedAtGeneratorPresets') ?? -1;
    if (sourceUpdatedAt == null || (ourUpdatedAt > 0 && sourceUpdatedAt <= ourUpdatedAt)) {
      l.d('Supplied config for import is not newer than our current one so we are ignoring it.');
      return;
    }
    PasswordGeneratorProfileSettings settings;
    int newUpdatedDate = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (embedded != null) {
      try {
        newUpdatedDate = sourceUpdatedAt;
        settings = PasswordGeneratorProfileSettings.fromMap(embedded);
        settings = repairIfRequired(cubit, settings);
      } on Exception {
        l.w(
          'Embedded password generator profile settings corrupt. Will ignore and bump our local updated time to mark that as the newest known version to aid recovery on other devices.',
        );
        await Settings.setValue('embeddedConfigUpdatedAtGeneratorPresets', newUpdatedDate);
        return;
      }
    } else {
      settings = PasswordGeneratorProfileSettings([], [], 'High');
    }
    await Settings.setValue('generatorPresets', settings.toJson());
    await Settings.setValue('embeddedConfigUpdatedAtGeneratorPresets', newUpdatedDate);
    cubit.reloadFromSettings(settings);
  }

  // We generally expect the persisted data to be correct but if we find bugs in future, or
  // for the known situation where a user of the PWA can set a disabled profile to be
  // the default, we can make rare fixups to the incoming data here.
  static PasswordGeneratorProfileSettings repairIfRequired(
    GeneratorProfilesCubit cubit,
    PasswordGeneratorProfileSettings settings,
  ) {
    if (settings.disabled.contains(settings.defaultProfileName)) {
      final newDefaultName = cubit.determineNewDefaultProfileName(
        settings.defaultProfileName,
        settings.disabled,
        settings.user,
      );
      return settings.copyWith(defaultProfileName: newDefaultName);
    }
    return settings;
  }
}
