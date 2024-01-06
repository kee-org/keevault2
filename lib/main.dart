import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keevault/config/platform.dart';
import 'package:keevault/logging/logger.dart';
import 'package:keevault/payment_service.dart';
import 'package:keevault/widgets/dialog_utils.dart';
import 'package:logger/logger.dart';
import 'package:matomo_tracker/matomo_tracker.dart' hide Level;
import 'package:public_suffix/public_suffix.dart';
import 'vault_backend/exceptions.dart';
import 'widgets/kee_vault_app.dart';
import './generated/l10n.dart';
import './extension_methods.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

void main() async {
  Logger.level = Level.trace;
  recordLibraryLogs();
  l.i('Initialized logger');

  final navigatorKey = GlobalKey<NavigatorState>();

  await runZonedGuarded<Future<void>>(
    () async {
      await Settings.init(cacheProvider: SharePreferenceCache());
      await MatomoTracker.instance.initialize(
        siteId: 7,
        url: 'https://matomo.kee.pm/js/',
        dispatchSettings: DispatchSettings.persistent(onLoad: DispatchSettings.whereNotOlderThan(Duration(days: 14))),
      );
      if (!KeeVaultPlatform.isWeb) {
        // Responsibility to check initialisation completed is deferred to any
        // Flutter views that actually want to use the IAP feature
        unawaited(PaymentService.instance.initConnection());
      }
      WidgetsFlutterBinding.ensureInitialized();
      l.i('Initialized WidgetsFlutterBinding');
      var suffixList = await rootBundle.loadString('assets/public_suffix_list.dat');
      DefaultSuffixRules.initFromString(suffixList);
      l.i('Initialized PSL');
      runApp(KeeVaultApp(navigatorKey: navigatorKey));
    },
    (dynamic error, StackTrace stackTrace) {
      if (error is KeeLoginFailedMITMException) {
        l.f('MITM attack detected!', error: error, stackTrace: stackTrace);
        navigatorKey.currentState?.overlay?.context.let((context) {
          var message =
              'Sign in failed because the response we received from the server indicates that it may be compromised. The most likely explanation is that someone near you or at your internet service provider is attempting to interfere with the secure connection and connect you to a malicious server (A Miscreant In The Middle attack). Find a different internet connection immediately, shut down the Kee Vault app and then try again. If it keeps happening, your local device may be compromised. The security of your Kee Vault remains intact so you need not panic. More information about the error is available at https://forum.kee.pm/';
          try {
            message = S.of(context).serverMITMWarning;
          } catch (e, stackTrace) {
            l.w('Error while localising error message', error: e, stackTrace: stackTrace);
          }
          DialogUtils.showErrorDialog(context, null, message);
          MatomoTracker.instance.trackEvent(eventInfo: EventInfo(category: 'main', action: 'error', name: 'mitm'));
        });
      } else if (error is FlutterError &&
          error.message.startsWith('Scaffold.geometryOf() must only be accessed during the paint phase.')) {
        l.w("Known Flutter bug ignored: 'Scaffold.geometryOf() must only be accessed during the paint phase.' This is known to be caused by tap interactions while the animations package is actively animating from an entrylistitem to an entry for editing. Other potential causes should be investigated if this is unlikely to have been the cause in this specific situation.");
      } else {
        l.f('Unhandled error in app.', error: error, stackTrace: stackTrace);
        navigatorKey.currentState?.overlay?.context.let((context) {
          var message = 'Unexpected error: $error';
          try {
            message = S.of(context).unexpected_error('$error');
          } catch (e, stackTrace) {
            l.w('Error while localising error message', error: e, stackTrace: stackTrace);
          }
          DialogUtils.showErrorDialog(context, null, '$message : $stackTrace');
          MatomoTracker.instance.trackEvent(eventInfo: EventInfo(category: 'main', action: 'error', name: 'wtf'));
        });
      }
    },
  );
}
