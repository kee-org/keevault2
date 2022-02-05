import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';
import 'package:keevault/widgets/help.dart';
import 'package:keevault/widgets/import_export.dart';
import 'package:keevault/widgets/password_generator.dart';
import 'package:keevault/widgets/password_preset_manager.dart';
import 'package:keevault/widgets/settings.dart';
import 'package:keevault/widgets/vault.dart';
import '../widgets/root.dart';

var rootHandler = Handler(handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
  return const RootWidget();
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
