import 'package:flutter/material.dart';
import 'package:keevault/widgets/bottom.dart';
import 'package:logger_flutter/logger_flutter.dart';
import 'package:matomo/matomo.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../generated/l10n.dart';

import 'dialog_utils.dart';

class HelpWidget extends TraceableStatefulWidget {
  const HelpWidget({
    Key? key,
  }) : super(key: key);

  @override
  _HelpWidgetState createState() => _HelpWidgetState();
}

class _HelpWidgetState extends State<HelpWidget> {
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
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final str = S.of(context);
    return Scaffold(
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
                Text(
                    "Something not quite right? Don't worry, our community forum will help you and you can start your own topic if you can't find what you need already."),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: OutlinedButton(
                      onPressed: () => {DialogUtils.openUrl('https://forum.kee.pm')}, child: Text(str.visitTheForum)),
                ),
                Divider(),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                  child: Text(
                    'Diagnostics',
                    style: theme.textTheme.headline6,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text('For you or others to be able to help, you may need to refer to the information below.'),
                ),
                Text('Application name: ${_packageInfo.appName}'),
                Text('Application version: ${_packageInfo.version}'),
                Text('Build number: ${_packageInfo.buildNumber}'),
                Text('Package ID: ${_packageInfo.packageName}'),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: OutlinedButton(onPressed: () => {LogConsole.open(context)}, child: Text('Show log console')),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomBarWidget(() => toggleBottomDrawerVisibility(context)),
    );
  }
}
