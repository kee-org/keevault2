import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';
import 'package:keevault/logging/log_console.dart';
import 'package:keevault/widgets/account_create.dart';
import 'package:keevault/widgets/change_subscription.dart';
import 'package:keevault/widgets/help.dart';
import 'package:keevault/widgets/import_export.dart';
import 'package:keevault/widgets/password_generator.dart';
import 'package:keevault/widgets/password_preset_manager.dart';
import 'package:keevault/widgets/settings.dart';
import 'package:keevault/widgets/vault.dart';
import '../widgets/blocking_overlay.dart';
import '../widgets/change_email_prefs.dart';
import '../widgets/change_password.dart';
import '../widgets/root.dart' as kv_root;

var rootHandler = Handler(handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
  return const kv_root.RootWidget();
});

var vaultHandler = Handler(handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
  return const VaultWidget();
});

var passwordGeneratorHandler = Handler(handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
  return const PasswordGeneratorWidget();
});

var importExportHandler = Handler(handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
  return const ImportExportWidget();
});

var settingsHandler = Handler(handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
  return const SettingsWidget();
});

var passwordPresetManagerHandler = Handler(handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
  return const PasswordPresetManagerWidget();
});

var helpHandler = Handler(handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
  return const HelpWidget();
});

var loggerHandler = Handler(handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
  return LogConsole();
});

var changePasswordHandler = Handler(handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
  return const ChangePasswordWidget();
});

var changeEmailPrefsHandler = Handler(handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
  return const ChangeEmailPrefsWidget();
});

var changeSubscriptionHandler = Handler(handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
  return const ChangeSubscriptionWidget();
});

var createAccountHandler = Handler(handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
  return BlockingOverlay(child: AccountCreateWidget(emailAddress: params['email']?[0]));
});
