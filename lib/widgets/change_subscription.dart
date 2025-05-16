import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/vault_backend/user.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/environment_config.dart';
import '../cubit/account_cubit.dart';
import '../generated/l10n.dart';
import 'coloured_safe_area_widget.dart';
import 'dialog_utils.dart';

class ChangeSubscriptionWidget extends StatefulWidget {
  const ChangeSubscriptionWidget({super.key});

  @override
  State<ChangeSubscriptionWidget> createState() => _ChangeSubscriptionWidgetState();
}

class _ChangeSubscriptionWidgetState extends State<ChangeSubscriptionWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);

    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, accountState) {
        List<Widget> children = [Text(str.settingsNotSignedInError)];

        if (accountState is AccountAuthenticated) {
          final subStatus = accountState.user.subscriptionStatus;
          final intro = Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              '${subStatus == AccountSubscriptionStatus.current ? 'Thanks for being a Kee Vault Supporter! Your Subscription is' : 'You do not currently have an active Kee Vault account. Your Subscription was previously'} provided by ${accountState.user.subscriptionSource.displayName()}.',
            ),
          );
          if (accountState.user.subscriptionSource == AccountSubscriptionSource.chargeBee) {
            children = [
              intro,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '${subStatus == AccountSubscriptionStatus.current ? 'View, change or cancel' : 'Restart'} your Subscription using the Kee Vault Account management site in your web browser.',
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  icon: Text(str.manageAccount),
                  label: Icon(Icons.open_in_new),
                  onPressed: () async {
                    await DialogUtils.openUrl(
                      EnvironmentConfig.webUrl + '/#pfEmail=${accountState.user.email},dest=manageAccount',
                    );
                  },
                ),
              ),
            ];
          } else if (accountState.user.subscriptionSource == AccountSubscriptionSource.googlePlay) {
            children = [
              intro,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '${subStatus == AccountSubscriptionStatus.current ? 'View, change or cancel' : 'Restart'} your Subscription using your Google Play Account.',
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  icon: Text(str.manageAccount),
                  label: Icon(Icons.open_in_new),
                  onPressed:
                      () async => launchUrl(
                        Uri.parse(
                          'https://play.google.com/store/account/subscriptions?sku=supporter&package=com.keevault.keevault',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                ),
              ),
            ];
          } else if (accountState.user.subscriptionSource == AccountSubscriptionSource.appleAppStore) {
            children = [
              intro,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '${subStatus == AccountSubscriptionStatus.current ? 'View, change or cancel' : 'Restart'} your Subscription using your Apple Account.',
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  icon: Text(str.manageAccount),
                  label: Icon(Icons.open_in_new),
                  onPressed:
                      () async => launchUrl(
                        Uri.parse('https://apps.apple.com/account/subscriptions'),
                        mode: LaunchMode.externalApplication,
                      ),
                ),
              ),
            ];
          } else {
            children = [
              intro,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Please ask on the community forum for assistance since we are currently unable to identify any method by which you can adjust your subscription.',
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: OutlinedButton(
                  onPressed: () async => await DialogUtils.openUrl('https://forum.kee.pm'),
                  child: Text(str.visitTheForum),
                ),
              ),
            ];
          }
          children.add(
            Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(str.subscriptionCancellationNotes)),
          );

          children.add(
            Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(str.accountDeletionNotes)),
          );

          children.add(
            Align(
              alignment: Alignment.center,
              child: OutlinedButton(
                onPressed: () async => await DialogUtils.openUrl('https://kee.pm/keevault/delete-account/'),
                style: OutlinedButton.styleFrom(backgroundColor: theme.buttonTheme.colorScheme!.error),
                child: Text(str.deleteAccount),
              ),
            ),
          );
        }

        return ColouredSafeArea(
          child: Scaffold(
            key: widget.key,
            appBar: AppBar(title: Text(str.yourSubscription)),
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
      },
    );
  }
}
