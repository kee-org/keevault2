import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

import '../model/in_app_message.dart';

part 'app_settings_state.dart';

class AppSettingsCubit extends Cubit<AppSettingsState> {
  AppSettingsCubit()
      : super(AppSettingsBasic(
          getThemeMode(Settings.getValue<String>('theme') ?? 'sys'),
          Settings.getValue<bool>('introShownVaultSummary') ?? false,
          InAppMessage.fromAppSetting('iamEmailSignup'),
          InAppMessage.fromAppSetting('iamMakeMoreChangesOrSave'),
          InAppMessage.fromAppSetting('iamSavingVault'),
          InAppMessage.fromAppSetting('iamAutofillDisabled'),
        ));

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

  Future<void> iamEmailSignupSuppressUntil(DateTime suppressUntil) async {
    final asbState = state as AppSettingsBasic;
    final newMessageState = asbState.iamEmailSignup.copyWith(suppressUntilTime: suppressUntil);
    await Settings.setValue('iamEmailSignup', newMessageState.toJson());
    emit((state as AppSettingsBasic).copyWith(iamEmailSignup: newMessageState));
  }

  Future<void> iamMakeMoreChangesOrSaveSuppressUntil(DateTime suppressUntil) async {
    final asbState = state as AppSettingsBasic;
    final newMessageState = asbState.iamMakeMoreChangesOrSave.copyWith(suppressUntilTime: suppressUntil);
    await Settings.setValue('iamMakeMoreChangesOrSave', newMessageState.toJson());
    emit((state as AppSettingsBasic).copyWith(iamMakeMoreChangesOrSave: newMessageState));
  }

  Future<void> iamSavingVaultSuppressUntil(DateTime suppressUntil) async {
    final asbState = state as AppSettingsBasic;
    final newMessageState = asbState.iamSavingVault.copyWith(suppressUntilTime: suppressUntil);
    await Settings.setValue('iamSavingVault', newMessageState.toJson());
    emit((state as AppSettingsBasic).copyWith(iamSavingVault: newMessageState));
  }

  Future<void> iamAutofillDisabledSuppressUntil(DateTime suppressUntil) async {
    final asbState = state as AppSettingsBasic;
    final newMessageState = asbState.iamAutofillDisabled.copyWith(suppressUntilTime: suppressUntil);
    await Settings.setValue('iamAutofillDisabled', newMessageState.toJson());
    emit((state as AppSettingsBasic).copyWith(iamAutofillDisabled: newMessageState));
  }

  Future<void> iamDisplayed(iamName) async {
    switch (iamName) {
      case 'iamEmailSignup':
        await _iamEmailSignupDisplayed();
        break;
      case 'iamMakeMoreChangesOrSave':
        await _iamMakeMoreChangesOrSaveDisplayed();
        break;
      case 'iamSavingVault':
        await _iamSavingVaultDisplayed();
        break;
      case 'iamAutofillDisabled':
        await _iamAutofillDisabledDisplayed();
        break;
    }
  }

  Future<void> _iamEmailSignupDisplayed() async {
    final asbState = state as AppSettingsBasic;
    final newMessageState = asbState.iamEmailSignup.copyWith(lastDisplayed: DateTime.now().toUtc());
    await Settings.setValue('iamEmailSignup', newMessageState.toJson());
    emit((state as AppSettingsBasic).copyWith(iamEmailSignup: newMessageState));
  }

  Future<void> _iamMakeMoreChangesOrSaveDisplayed() async {
    final asbState = state as AppSettingsBasic;
    final newMessageState = asbState.iamMakeMoreChangesOrSave.copyWith(lastDisplayed: DateTime.now().toUtc());
    await Settings.setValue('iamMakeMoreChangesOrSave', newMessageState.toJson());
    emit((state as AppSettingsBasic).copyWith(iamMakeMoreChangesOrSave: newMessageState));
  }

  Future<void> _iamSavingVaultDisplayed() async {
    final asbState = state as AppSettingsBasic;
    final newMessageState = asbState.iamSavingVault.copyWith(lastDisplayed: DateTime.now().toUtc());
    await Settings.setValue('iamSavingVault', newMessageState.toJson());
    emit((state as AppSettingsBasic).copyWith(iamSavingVault: newMessageState));
  }

  Future<void> _iamAutofillDisabledDisplayed() async {
    final asbState = state as AppSettingsBasic;
    final newMessageState = asbState.iamAutofillDisabled.copyWith(lastDisplayed: DateTime.now().toUtc());
    await Settings.setValue('iamAutofillDisabled', newMessageState.toJson());
    emit((state as AppSettingsBasic).copyWith(iamAutofillDisabled: newMessageState));
  }
}
