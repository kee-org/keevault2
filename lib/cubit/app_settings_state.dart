part of 'app_settings_cubit.dart';

@immutable
abstract class AppSettingsState {}

class AppSettingsBasic extends AppSettingsState {
  final ThemeMode themeMode;
  final bool introShownVaultSummary;

  AppSettingsBasic(this.themeMode, this.introShownVaultSummary);
}
