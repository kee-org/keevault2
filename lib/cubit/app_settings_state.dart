part of 'app_settings_cubit.dart';

@immutable
abstract class AppSettingsState {}

class AppSettingsBasic extends AppSettingsState {
  final ThemeMode themeMode;
  final bool introShownVaultSummary;
  final InAppMessage iamEmailSignup;
  final InAppMessage iamMakeMoreChangesOrSave;
  final InAppMessage iamSavingVault;
  final InAppMessage iamAutofillDisabled;

  AppSettingsBasic(
    this.themeMode,
    this.introShownVaultSummary,
    this.iamEmailSignup,
    this.iamMakeMoreChangesOrSave,
    this.iamSavingVault,
    this.iamAutofillDisabled,
  );

  AppSettingsBasic copyWith({
    ThemeMode? themeMode,
    bool? introShownVaultSummary,
    InAppMessage? iamEmailSignup,
    InAppMessage? iamMakeMoreChangesOrSave,
    InAppMessage? iamSavingVault,
    InAppMessage? iamAutofillDisabled,
  }) {
    return AppSettingsBasic(
      themeMode ?? this.themeMode,
      introShownVaultSummary ?? this.introShownVaultSummary,
      iamEmailSignup ?? this.iamEmailSignup,
      iamMakeMoreChangesOrSave ?? this.iamMakeMoreChangesOrSave,
      iamSavingVault ?? this.iamSavingVault,
      iamAutofillDisabled ?? this.iamAutofillDisabled,
    );
  }

  InAppMessage iamFromName(String iamName) {
    switch (iamName) {
      case 'iamEmailSignup':
        {
          return iamEmailSignup;
        }
      case 'iamMakeMoreChangesOrSave':
        {
          return iamMakeMoreChangesOrSave;
        }
      case 'iamSavingVault':
        {
          return iamSavingVault;
        }
      case 'iamAutofillDisabled':
        {
          return iamAutofillDisabled;
        }
    }
    throw Exception('Unknown iam name: $iamName');
  }
}
