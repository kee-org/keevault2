import 'dart:async';

import 'package:flutter/material.dart';
import 'package:keevault/widgets/bottom.dart';
import 'package:logger_flutter/logger_flutter.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../generated/l10n.dart';

import 'coloured_safe_area_widget.dart';
import 'dialog_utils.dart';

class HelpWidget extends StatefulWidget {
  const HelpWidget({
    Key? key,
  }) : super(key: key);

  @override
  State<HelpWidget> createState() => _HelpWidgetState();
}

class _HelpWidgetState extends State<HelpWidget> with TraceableClientMixin {
  @override
  String get traceTitle => widget.toStringShort();

  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    unawaited(_initPackageInfo());
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _packageInfo = info;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final str = S.of(context);
    return ColouredSafeArea(
      child: Scaffold(
        key: widget.key,
        appBar: AppBar(title: Text(str.help)),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SafeArea(
              top: false,
              left: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: Text(
                      'Documentation',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Text(
                      "We have carefully designed Kee Vault so that the fastest way for you to work out how to use it should be discoverable directly within the app itself so don't be afraid to try ideas out yourself - you're probably right! For some of the more complex aspects of the app or Kee Vault service, we maintain a set of documents on our community forum."),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: OutlinedButton(
                        onPressed: () async =>
                            await DialogUtils.openUrl('https://forum.kee.pm/tags/c/kee-vault/9/documentation'),
                        child: Text(str.viewDocumentation)),
                  ),
                  Divider(),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: Text(
                      'Feedback and other support',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Text(
                      "Something not quite right? Don't worry, our community forum will help you and you can start your own topic if you can't find what you need already."),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: OutlinedButton(
                        onPressed: () async => await DialogUtils.openUrl('https://forum.kee.pm'),
                        child: Text(str.visitTheForum)),
                  ),
                  Divider(),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: Text(
                      'Diagnostics',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child:
                        Text('For you or others to be able to help, you may need to refer to the information below.'),
                  ),
                  Text('Application name: ${_packageInfo.appName}'),
                  Text('Application version: ${_packageInfo.version}'),
                  Text('Build number: ${_packageInfo.buildNumber}'),
                  Text('Package ID: ${_packageInfo.packageName}'),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: OutlinedButton(
                        onPressed: () async => await LogConsole.open(context), child: Text('Show log console')),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: BottomBarWidget(() => toggleBottomDrawerVisibility(context)),
      ),
    );
  }
}
