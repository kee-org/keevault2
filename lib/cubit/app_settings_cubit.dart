import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

part 'app_settings_state.dart';

class AppSettingsCubit extends Cubit<AppSettingsState> {
  AppSettingsCubit()
      : super(AppSettingsBasic(getThemeMode(Settings.getValue<String>('theme', 'sys')),
            Settings.getValue('introShownVaultSummary', false)));

  static ThemeMode getThemeMode(String brightness) {
    if (brightness == 'lt') return ThemeMode.light;
    if (brightness == 'dk') return ThemeMode.dark;
    return ThemeMode.system;
  }

  void changeTheme(String brightness) {
    emit(AppSettingsBasic(getThemeMode(brightness), (state as AppSettingsBasic).introShownVaultSummary));
  }

  void completeIntroShownVaultSummary() async {
    await Settings.setValue('introShownVaultSummary', !(state as AppSettingsBasic).introShownVaultSummary);
    emit(AppSettingsBasic((state as AppSettingsBasic).themeMode, !(state as AppSettingsBasic).introShownVaultSummary));
  }
}
