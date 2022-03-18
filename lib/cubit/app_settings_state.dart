part of 'app_settings_cubit.dart';

@immutable
abstract class AppSettingsState {}

class AppSettingsBasic extends AppSettingsState {
  final ThemeMode themeMode;
  final bool introShownVaultSummary;
  final InAppMessage iamEmailSignup;

  AppSettingsBasic(this.themeMode, this.introShownVaultSummary, this.iamEmailSignup);

  AppSettingsBasic copyWith({
    ThemeMode? themeMode,
    bool? introShownVaultSummary,
    InAppMessage? iamEmailSignup,
  }) {
    return AppSettingsBasic(
      themeMode ?? this.themeMode,
      introShownVaultSummary ?? this.introShownVaultSummary,
      iamEmailSignup ?? this.iamEmailSignup,
    );
  }
}
