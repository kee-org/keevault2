import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/vault_backend/user.dart';
import '../config/environment_config.dart';
import '../cubit/account_cubit.dart';
import '../generated/l10n.dart';
import 'coloured_safe_area_widget.dart';
import 'dialog_utils.dart';

class ChangeEmailPrefsWidget extends StatefulWidget {
  const ChangeEmailPrefsWidget({Key? key}) : super(key: key);

  @override
  State<ChangeEmailPrefsWidget> createState() => _ChangeEmailPrefsWidgetState();
}

class _ChangeEmailPrefsWidgetState extends State<ChangeEmailPrefsWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);

    return BlocBuilder<AccountCubit, AccountState>(builder: (context, accountState) {
      List<Widget> children = [Text(str.settingsNotSignedInError)];
      if (accountState is AccountAuthenticated) {
        if (accountState.user.subscriptionSource == AccountSubscriptionSource.chargeBee) {
          children = [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                  'View and change your email preferences using the Kee Vault Account management site in your web browser.'),
            ),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                icon: Text(str.manageAccount),
                label: Icon(Icons.open_in_new),
                onPressed: () async {
                  await DialogUtils.openUrl(
                      EnvironmentConfig.webUrl + '/#pfEmail=${accountState.user.email},dest=manageAccount');
                },
              ),
            ),
          ];
        } else {
          children = [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                  'Unsubscribe from any emails you do not want to receive more of when the next email arrives. We do not yet support the viewing of current email preferences or the ability to resubscribe to our marketing emails.'),
            ),
          ];
        }
      }

      return ColouredSafeArea(
        child: Scaffold(
          key: widget.key,
          appBar: AppBar(title: Text(str.changeEmailPrefs)),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SafeArea(
                top: false,
                left: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
              ),
            ),
          ),
        ),
      );
    });
  }
}
