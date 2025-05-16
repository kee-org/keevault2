import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';
import 'package:keevault/logging/logger.dart';
import './route_handlers.dart';

class Routes {
  static String root = '/';
  static String vault = '/vault';
  static String passwordGenerator = '/password_generator';
  static String passwordPresetManager = '/password_preset_manager';
  static String importExport = '/import_export';
  static String settings = '/settings';
  static String help = '/help';
  static String logger = '/logger';
  static String changePassword = '/change_password';
  static String changeEmailPrefs = '/change_email_prefs';
  static String changeSubscription = '/change_subscription';
  static String createAccount = '/create_account/:email';

  static void configureRoutes(FluroRouter router) {
    router.notFoundHandler = Handler(
      handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
        l.e('ROUTE WAS NOT FOUND!');
        return const Text('Fatal application error. Route not found. Tell us about this because it will never happen.');
      },
    );
    router.define(root, handler: rootHandler);
    router.define(vault, handler: vaultHandler);
    router.define(passwordGenerator, handler: passwordGeneratorHandler);
    router.define(importExport, handler: importExportHandler);
    router.define(settings, handler: settingsHandler);
    router.define(passwordPresetManager, handler: passwordPresetManagerHandler);
    router.define(help, handler: helpHandler);
    router.define(logger, handler: loggerHandler);
    router.define(changePassword, handler: changePasswordHandler);
    router.define(changeEmailPrefs, handler: changeEmailPrefsHandler);
    router.define(changeSubscription, handler: changeSubscriptionHandler);
    router.define(createAccount, handler: createAccountHandler);
  }
}
