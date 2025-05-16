import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/widgets/bottom.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app.dart';
import '../config/routes.dart';
import '../cubit/account_cubit.dart';
import '../cubit/vault_cubit.dart';
import '../generated/l10n.dart';

import 'coloured_safe_area_widget.dart';
import 'dialog_utils.dart';
import '../logging/logger.dart';

class HelpWidget extends StatefulWidget {
  const HelpWidget({super.key});

  @override
  State<HelpWidget> createState() => _HelpWidgetState();
}

class _HelpWidgetState extends State<HelpWidget> with TraceableClientMixin {
  @override
  String get actionName => widget.toStringShort();

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
                    child: Text('Documentation', style: theme.textTheme.titleLarge),
                  ),
                  Text(
                    "We have carefully designed Kee Vault so that the fastest way for you to work out how to use it should be discoverable directly within the app itself so don't be afraid to try ideas out yourself - you're probably right! For some of the more complex aspects of the app or Kee Vault service, we maintain a set of documents on our community forum.",
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: OutlinedButton(
                      onPressed:
                          () async =>
                              await DialogUtils.openUrl('https://forum.kee.pm/tags/c/kee-vault/9/documentation'),
                      child: Text(str.viewDocumentation),
                    ),
                  ),
                  Divider(),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: Text('Feedback and other support', style: theme.textTheme.titleLarge),
                  ),
                  Text(
                    "Something not quite right? Don't worry, our community forum will help you and you can start your own topic if you can't find what you need already.",
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: OutlinedButton(
                      onPressed: () async => await DialogUtils.openUrl('https://forum.kee.pm'),
                      child: Text(str.visitTheForum),
                    ),
                  ),
                  Divider(),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: Text('Diagnostics', style: theme.textTheme.titleLarge),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'For you or others to be able to help, you may need to refer to the information below.',
                    ),
                  ),
                  Text('Application name: ${_packageInfo.appName}'),
                  Text('Application version: ${_packageInfo.version}'),
                  Text('Build number: ${_packageInfo.buildNumber}'),
                  Text('Package ID: ${_packageInfo.packageName}'),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: OutlinedButton(
                      onPressed:
                          () async =>
                              await AppConfig.router.navigateTo(AppConfig.navigatorKey.currentContext!, Routes.logger),
                      child: Text('Share / view logs'),
                    ),
                  ),
                  PendingUpdateErrorRecoveryWidget(theme: theme),
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

class PendingUpdateErrorRecoveryWidget extends StatefulWidget {
  const PendingUpdateErrorRecoveryWidget({super.key, required this.theme});

  final ThemeData theme;

  @override
  State<PendingUpdateErrorRecoveryWidget> createState() => _PendingUpdateErrorRecoveryWidgetState();
}

class _PendingUpdateErrorRecoveryWidgetState extends State<PendingUpdateErrorRecoveryWidget> {
  bool? _errorAndPendingUpdateKdbxExists;

  @override
  void initState() {
    super.initState();
    unawaited(_detectPendingUpdateKdbx());
  }

  Future<void> _detectPendingUpdateKdbx() async {
    final accountCubit = BlocProvider.of<AccountCubit>(context);
    final currentUser = accountCubit.currentUserIfKnown;
    // Only bother if user is signed in account holder, not a free local only user
    // and if we might care whether the file exists or not
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    if (vaultCubit.state is! VaultError || accountCubit.state is AccountLocalOnly || currentUser == null) {
      setState(() {
        _errorAndPendingUpdateKdbxExists = false;
      });
      return;
    }
    final pendingUpdateKdbxExists = await vaultCubit.hasPendingUpdateFile(currentUser);
    setState(() {
      _errorAndPendingUpdateKdbxExists = pendingUpdateKdbxExists;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VaultCubit, VaultState>(
      builder: (context, state) {
        final vc = BlocProvider.of<VaultCubit>(context);
        final ac = BlocProvider.of<AccountCubit>(context);
        final currentUser = ac.currentUserIfKnown;
        return Visibility(
          visible: _errorAndPendingUpdateKdbxExists ?? false,
          child: Column(
            children: [
              Divider(),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: Text('Error recovery', style: widget.theme.textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'There is a version of your Kee Vault pending merge with your current local version. This is a rare but expected behaviour in some cases of a failed download from the internet but once any fault with your device has been resolved, Kee Vault should automatically complete the merge when you sign-in to your Kee Vault.',
                ),
              ),
              Text(
                'If you are experiencing an error that prevents the opening of your Kee Vault because this downloaded data is in some way corrupt or incompatible with your Kee Vault on this device, the button below may help. If the underlying fault with the previous download attempt has not been resolved, the error may re-appear and in very rare circumstances you may lose data (e.g. during certain offline modifications across multiple devices).',
              ),
              Text(
                'Ensure you understand the cause of your error situation and the implications of clicking the button - we recommend discussing the problem in the community forum before taking any action.',
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: FilledButton(
                  onPressed: () async {
                    final proceed = await DialogUtils.showConfirmDialog(
                      context: context,
                      params: ConfirmDialogParams(
                        content:
                            'If you delete this data we will attempt to re-download the latest version shortly after you next sign-in. After deleting this data, you must use your task manager to kill Kee Vault and then start it again (or restart your device if you are unsure how to do this). Ensure that you have resolved the underlying fault before proceeding (e.g. made more disk space available on your device or repaired the hardware fault on the device) and that you have a good network connection. Are you sure you want to delete the data?',
                        negativeButtonText: 'Keep',
                        positiveButtonText: 'Delete',
                        title: 'Delete version of your Kee Vault data that is pending merge',
                      ),
                    );
                    if (proceed) {
                      l.w('deletePendingUpdateFile');
                      await vc.deletePendingUpdateFile(currentUser!);
                      await _detectPendingUpdateKdbx();
                    }
                    l.i('deletePendingUpdateFile skipped by user');
                  },
                  style: FilledButton.styleFrom(backgroundColor: widget.theme.buttonTheme.colorScheme!.error),
                  child: Text('Delete pending Kee Vault data'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
