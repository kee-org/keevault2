import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/cubit/account_cubit.dart';
import '../generated/l10n.dart';
import '../vault_backend/exceptions.dart';

typedef SubmitCallback = Future<void> Function(String string);

class AccountEmailNotVerifiedWidget extends StatefulWidget {
  const AccountEmailNotVerifiedWidget({
    super.key,
  });

  @override
  State<AccountEmailNotVerifiedWidget> createState() => _AccountEmailNotVerifiedWidgetState();
}

class _AccountEmailNotVerifiedWidgetState extends State<AccountEmailNotVerifiedWidget> {
  Future<void> resendEmail() async {
    setState(() {
      disableResending = true;
      resending = true;
    });
    final accountCubit = BlocProvider.of<AccountCubit>(context);
    final wasSent = await accountCubit.resendVerificationEmail();
    // Keep spinning for a couple of seconds to help user email deliverability
    // experience, unless we know it failed.
    // Keep disabled for 60 seconds, or 5 if it failed.
    if (!wasSent) {
      if (mounted) {
        setState(() {
          resending = false;
        });
      }
      await Future.delayed(Duration(seconds: 5));
      if (mounted) {
        setState(() {
          disableResending = false;
        });
      }
    } else {
      await Future.delayed(Duration(seconds: 2));
      if (mounted) {
        setState(() {
          resending = false;
        });
      }
      await Future.delayed(Duration(seconds: 58));
      if (mounted) {
        setState(() {
          disableResending = false;
        });
      }
    }
  }

  Future<void> refreshUserAndTokens() async {
    setState(() {
      disableRefreshing = true;
      refreshing = true;
    });
    try {
      for (var i = 0; i < 3; i++) {
        try {
          final accountCubit = BlocProvider.of<AccountCubit>(context);
          await accountCubit.refreshUserAndTokens();
          break;
        } on KeeAccountUnverifiedException {
          // retry automatically so user can't keep spamming the button in case dynamodb
          // is taking some time to update after their verification or they are
          // verifying an old email address
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          refreshing = false;
        });
      }
      await Future.delayed(Duration(seconds: 5));
      if (mounted) {
        setState(() {
          disableRefreshing = false;
        });
      }
    }
  }

  bool disableResending = true;
  bool disableRefreshing = true;
  bool resending = false;
  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_enableButtonsAfterDelay());
  }

  Future<void> _enableButtonsAfterDelay() async {
    await Future.delayed(Duration(seconds: 5));
    if (mounted) {
      setState(() {
        disableRefreshing = false;
        disableResending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<AccountCubit, AccountState>(builder: (context, state) {
      if (state is AccountEmailNotVerified) {
        final userEmail = state.user.email;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                str.emailVerification,
                style: theme.textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                str.verificationRequest(userEmail ?? 'error - unknown email address - contact us for help'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            OutlinedButton(
              onPressed: disableResending
                  ? null
                  : () async {
                      await resendEmail();
                    },
              child: resending
                  ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        strokeWidth: 3,
                      ),
                    )
                  : Text(str.resendVerification),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                str.signInAgainWhenVerified,
                textAlign: TextAlign.center,
              ),
            ),
            ElevatedButton(
              onPressed: disableRefreshing
                  ? null
                  : () async {
                      await refreshUserAndTokens();
                    },
              child: refreshing
                  ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        strokeWidth: 3,
                      ),
                    )
                  : Text('Continue signing in'),
            ),
          ]),
        );
      } else {
        return Text(str.unexpected_error('Account in invalid state for AccountEmailNotVerifiedWidget'));
      }
    });
  }
}
