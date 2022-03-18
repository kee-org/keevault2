import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

import '../model/in_app_message.dart';

part 'app_settings_state.dart';

class AppSettingsCubit extends Cubit<AppSettingsState> {
  AppSettingsCubit()
      : super(AppSettingsBasic(
            getThemeMode(Settings.getValue<String>('theme', 'sys')),
            Settings.getValue('introShownVaultSummary', false),
            InAppMessage.fromJson(Settings.getValue(
                'iamEmailSignup',
                InAppMessage(
                  DateTime.fromMillisecondsSinceEpoch(0),
                  Duration(days: 1),
                  Duration(days: 3),
                  DateTime.now().toUtc(),
                  7,
                  3,
                ).toJson()))));

  static ThemeMode getThemeMode(String brightness) {
    if (brightness == 'lt') return ThemeMode.light;
    if (brightness == 'dk') return ThemeMode.dark;
    return ThemeMode.system;
  }

  void changeTheme(String brightness) {
    emit((state as AppSettingsBasic).copyWith(themeMode: getThemeMode(brightness)));
  }

  Future<void> completeIntroShownVaultSummary() async {
    await Settings.setValue('introShownVaultSummary', true);
    emit((state as AppSettingsBasic).copyWith(introShownVaultSummary: true));
  }

  Future<void> iamEmailSignupDisplayed() async {
    final asbState = state as AppSettingsBasic;
    final newMessageState = asbState.iamEmailSignup.copyWith(lastDisplayed: DateTime.now().toUtc());
    await Settings.setValue('iamEmailSignup', newMessageState.toJson());
    emit((state as AppSettingsBasic).copyWith(iamEmailSignup: newMessageState));
  }

  Future<void> iamEmailSignupSuppressUntil(DateTime suppressUntil) async {
    final asbState = state as AppSettingsBasic;
    final newMessageState = asbState.iamEmailSignup.copyWith(suppressUntilTime: suppressUntil);
    await Settings.setValue('iamEmailSignup', newMessageState.toJson());
    emit((state as AppSettingsBasic).copyWith(iamEmailSignup: newMessageState));
  }
}
