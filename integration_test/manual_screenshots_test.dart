import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/config/platform.dart';
import 'package:keevault/widgets/kee_vault_app.dart';
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';
import 'package:public_suffix/public_suffix.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Obviously would be nicer if we could just script the screenshot operation rather than
  // introduce all these manual pauses and interventions but Patrol has removed support
  // for this in early 2023 and it's still not been fixed in June.
  patrolTest(
    'free user unlock and screenshot pauses',
    nativeAutomation: true,
    config: const PatrolTesterConfig(
      existsTimeout: Duration(seconds: 60),
      visibleTimeout: Duration(seconds: 60),
      settleTimeout: Duration(seconds: 60),
    ),
    timeout: Timeout(Duration(seconds: 600)),
    ($) async {
      // disable biometrics since we can't automate interaction with that
      await Settings.init(cacheProvider: SharePreferenceCache());
      await Settings.setValue('biometrics-enabled', false);
      await Settings.setValue('introShownVaultSummary', true);
//    await Settings.setValue('currentSortOrder', enumToString(mode));

      // install local user kdbx file for demo
      await createDemo();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user.current.isFree', true);

      // This is also done in the normal main method of the app but there are some things in there
      // we don't want to do. In future, could try to refactor that method and share the
      // relevant parts with this and other automated tests.
      final navigatorKey = GlobalKey<NavigatorState>();
      var suffixList = await rootBundle.loadString('assets/public_suffix_list.dat');
      DefaultSuffixRules.initFromString(suffixList);

      // Create app and unlock free user vault
      final myApp = KeeVaultApp(navigatorKey: navigatorKey);
      await $.pumpWidgetAndSettle(myApp);
      await Future.delayed(Duration(seconds: 1));
      expect($('Unlock'), findsOneWidget);
      await $(TextField).enterText('test');
      await $.tap($('Unlock'));
      await $(BottomAppBar).$(IconButton).waitUntilVisible();
      // Resetting here just in case test runner kills us before the change is flushed
      // and we can get a more interesting set of screenshots
      await Settings.setValue('biometrics-enabled', true);
      await Future.delayed(Duration(seconds: 4));

      await $(BottomAppBar).$(IconButton).tap();
      await $.tap($('Settings'));
      await Future.delayed(Duration(seconds: 4));

      await $(AppBar).$(IconButton).tap();
      await $(BottomAppBar).$(IconButton).waitUntilVisible().tap();
      await $.tap($('Generate single password'));
      await Future.delayed(Duration(seconds: 4));

      await $.native.enableDarkMode();
      await $(AppBar).$(IconButton).tap();
      await Future.delayed(Duration(seconds: 1));
      await $(AppBar).$(IconButton).tap();
      await $('Internet').tap();
      await Future.delayed(Duration(seconds: 4));

      await $(AppBar).$(IconButton).tap();
      await $(TextField).enterText('smi');
      await Future.delayed(Duration(seconds: 15));
      // May now need to manually show the keyboard before taking the screenshot
      // (e.g. on iPad / with physical keyboard attached)

      await $.native.disableDarkMode();
      await $('smith@gmail.com').tap();
      await Future.delayed(Duration(seconds: 8));

      // Patrol auto-uninstalls the app so autofill settings will be lost so if we ever need
      // to run with autofill enabled, we'll need to finish the work below on automating that configuration.

      // ios: Passwords -> Password Options
      // await $('Enable Autofill').waitUntilVisible().tap();
      // await Future.delayed(Duration(seconds: 3));
      // await $(TextButton).$('OK').waitUntilVisible();

      // //TODO:f: support android too
      // await $.native.openApp(appId: 'com.apple.Preferences');
      // await $.native.tap(
      //   Selector(text: 'Kee Vault'), // 'Kee Vault(d)' ? Also matches main settings for my app when running on iPad
      //   appId: 'com.apple.Preferences',
      // );
      // await $.native.tap(
      //   Selector(text: 'Keechain'),
      //   appId: 'com.apple.Preferences',
      // );
      // await $.native.openApp();

      // await $(TextButton).$('OK').tap();
    },
  );

  // patrolTest('autofill from safari facebook',
  //     nativeAutomation: true,
  //     config: const PatrolTesterConfig(
  //       existsTimeout: Duration(seconds: 60),
  //       visibleTimeout: Duration(seconds: 60),
  //       settleTimeout: Duration(seconds: 60),
  //     ),
  //     timeout: Timeout(Duration(seconds: 600)), ($) async {
  //   //TODO:f: Maybe automate this? Could be difficult since we disable
  // biometrics for integration testing and simulators don't support that well (nor autofill actually I
  // guess but maybe it'll work one day)
  // });
}

Future<void> createDemo() async {
  final directory = await getStorageDirectory();
  final kdbxBytes = await rootBundle.load('assets/Demo.kdbx');
  if (kdbxBytes.lengthInBytes > 0) {
    final file = File('${directory.path}/local_user/current.kdbx');
    await file.create(recursive: true);
    await file.writeAsBytes(kdbxBytes.buffer.asInt8List(), flush: true);
  } else {
    throw Exception('demo file not found in root bundle');
  }
}

getStorageDirectory() async {
  const autoFillMethodChannel = MethodChannel('com.keevault.keevault/autofill');
  if (KeeVaultPlatform.isIOS) {
    final path = await autoFillMethodChannel.invokeMethod('getAppGroupDirectory');
    return Directory(path);
  }
  final directory = await getApplicationSupportDirectory();
  return directory;
}
