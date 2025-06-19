import 'dart:async';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/cubit/account_cubit.dart';
import '../config/app.dart';
import '../config/routes.dart';
import '../cubit/vault_cubit.dart';
import '../generated/l10n.dart';
import '../logging/logger.dart';

typedef SubmitCallback = Future<void> Function(String string);

class AccountEmailChangeWidget extends StatefulWidget {
  const AccountEmailChangeWidget({super.key});

  @override
  State<AccountEmailChangeWidget> createState() => _AccountEmailChangeWidgetState();
}

class _AccountEmailChangeWidgetState extends State<AccountEmailChangeWidget> {
  Future<void> cancel() async {
    // We always sign the user out. Might be nice to send them back to their Vault if that's
    // where they came from (i.e. they have a validated and active account) but might be
    // hard to do securely so will ignore that edge case initially.
    final accountCubit = BlocProvider.of<AccountCubit>(context);
    await accountCubit.signout();
    await AppConfig.router.navigateTo(AppConfig.navigatorKey.currentContext!, Routes.root, clearStack: true);
  }

  Future<bool> changeEmailAddress(String password, String newEmailAddress) async {
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    if (vaultCubit.state is! VaultInitial) {
      l.e(
        'Vault is not in expected state so we will not proceed with the email address change. Found state: ${vaultCubit.state.runtimeType}',
      );
      return false;
    }
    setState(() {
      changing = true;
    });
    final accountCubit = BlocProvider.of<AccountCubit>(context);
    return await accountCubit.changeEmailAddress(password, newEmailAddress);
  }

  final _formKey = GlobalKey<FormState>();
  String? submittedValuePassword;
  String? submittedValueNewEmailAddress;
  final TextEditingController _currentPassword = TextEditingController();
  final TextEditingController _newEmailAddress = TextEditingController();
  bool passwordObscured = true;
  bool disableChange = true;
  bool changing = false;

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) {
        if (state is AccountEmailChangeRequested) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, Object? result) async {
              if (didPop) {
                return;
              }
              await cancel();
            },
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(str.changeEmail, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(str.changeEmailInfo1, textAlign: TextAlign.left),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(str.changeEmailInfo2, textAlign: TextAlign.left, style: theme.textTheme.bodyLarge),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(str.changeEmailInfo2a, textAlign: TextAlign.left),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32.0),
                      child: Text(str.changeEmailInfo2b, textAlign: TextAlign.left),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(str.changeEmailInfo3, textAlign: TextAlign.left, style: theme.textTheme.bodyLarge),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(str.changeEmailInfo3a, textAlign: TextAlign.left),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(str.changeEmailInfo3b, textAlign: TextAlign.left),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32.0),
                      child: Text(str.changeEmailInfo3c, textAlign: TextAlign.left),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(str.changeEmailInfo4, textAlign: TextAlign.left),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(str.changeEmailInfo5, textAlign: TextAlign.left),
                    ),
                    CheckboxListTile(
                      value: !disableChange,
                      title: Text(str.changeEmailConfirmCheckbox, style: theme.textTheme.labelLarge),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onChanged: (bool? value) {
                        setState(() {
                          disableChange = !value!;
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
                      child: TextFormField(
                        enabled: !disableChange,
                        controller: _newEmailAddress,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: str.newEmailAddress,
                          errorText: null,
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? false) {
                            return str.this_field_required;
                          }
                          return !EmailValidator.validate(value ?? '') ? str.emailValidationFail : null;
                        },
                        onSaved: (String? value) {
                          submittedValueNewEmailAddress = value;
                        },
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
                      child: TextFormField(
                        enabled: !disableChange,
                        controller: _currentPassword,
                        obscureText: passwordObscured,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: str.currentPassword,
                          errorText: null,
                          suffixIcon: IconButton(
                            icon: Icon(passwordObscured ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                passwordObscured = !passwordObscured;
                              });
                            },
                          ),
                          // suffixIconColor: theme.brightness == Brightness.light ? theme.primaryColor : Colors.white,
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? false) {
                            return str.this_field_required;
                          }
                          return null;
                        },
                        onSaved: (String? value) {
                          submittedValuePassword = value;
                        },
                        keyboardType: TextInputType.visiblePassword,
                      ),
                    ),
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          state.error!,
                          textAlign: TextAlign.left,
                          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: changing
                              ? null
                              : () async {
                                  await cancel();
                                },
                          child: changing
                              ? Container(
                                  width: 24,
                                  height: 24,
                                  padding: const EdgeInsets.all(2.0),
                                  child: const CircularProgressIndicator(strokeWidth: 3),
                                )
                              : Text(str.alertCancel),
                        ),
                        FilledButton(
                          onPressed: changing || disableChange
                              ? null
                              : () async {
                                  final sm = ScaffoldMessenger.of(context);
                                  if (_formKey.currentState!.validate()) {
                                    _formKey.currentState!.save();
                                    try {
                                      final result = await changeEmailAddress(
                                        submittedValuePassword!,
                                        submittedValueNewEmailAddress!,
                                      );
                                      if (result) {
                                        sm.showSnackBar(
                                          SnackBar(content: Text(str.emailChanged), duration: Duration(seconds: 6)),
                                        );
                                        await AppConfig.router.navigateTo(
                                          AppConfig.navigatorKey.currentContext!,
                                          Routes.root,
                                          clearStack: true,
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          changing = false;
                                        });
                                      }
                                    }
                                  }
                                },
                          child: changing
                              ? Container(
                                  width: 24,
                                  height: 24,
                                  padding: const EdgeInsets.all(2.0),
                                  child: const CircularProgressIndicator(strokeWidth: 3),
                                )
                              : Text(str.changeEmail),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          return Text(str.unexpected_error('Account in invalid state for AccountEmailChangeWidget'));
        }
      },
    );
  }
}
