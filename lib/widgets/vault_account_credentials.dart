import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:keevault/config/platform.dart';
import '../config/environment_config.dart';
import '../generated/l10n.dart';

typedef SubmitCallback = Future<void> Function(String string);

class VaultAccountCredentialsWidget extends StatefulWidget {
  const VaultAccountCredentialsWidget({
    super.key,
    required this.onSignInRequest,
    required this.onLocalOnlyRequested,
    required this.onRegisterRequest,
  });

  final SubmitCallback onSignInRequest;
  final void Function() onLocalOnlyRequested;
  final SubmitCallback onRegisterRequest;

  @override
  State<VaultAccountCredentialsWidget> createState() => _VaultAccountCredentialsWidgetState();
}

class _VaultAccountCredentialsWidgetState extends State<VaultAccountCredentialsWidget>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String? submittedValue;
  final registrationEnabled =
      (EnvironmentConfig.iapGooglePlay && KeeVaultPlatform.isAndroid) ||
      (EnvironmentConfig.iapAppleAppStore && KeeVaultPlatform.isIOS);
  bool newUser =
      (EnvironmentConfig.iapGooglePlay && KeeVaultPlatform.isAndroid) ||
      (EnvironmentConfig.iapAppleAppStore && KeeVaultPlatform.isIOS);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: 2);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          setState(() {
            newUser = true;
          });
        } else {
          setState(() {
            newUser = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> onSubmitButton() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      await registerOrSignin(submittedValue!);
    }
  }

  Future<void> registerOrSignin(String value) async {
    if (newUser) {
      await widget.onRegisterRequest(value);
    } else {
      await widget.onSignInRequest(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    final mainColor = theme.brightness == Brightness.dark ? theme.colorScheme.secondary : theme.colorScheme.primary;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(str.welcomeToKeeVault, style: theme.textTheme.headlineSmall),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                  border: Border.all(color: theme.colorScheme.primary, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Sign in ${registrationEnabled ? 'or Register for' : 'to'} your Kee Vault account',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(height: 1.2, color: mainColor),
                      ),
                    ),
                    if (registrationEnabled)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Theme(
                            data: theme.copyWith(
                              tabBarTheme: theme.tabBarTheme.copyWith(
                                labelColor: mainColor,
                                indicatorColor: mainColor,
                                indicatorSize: TabBarIndicatorSize.label,
                              ),
                            ),
                            child: Container(
                              padding: EdgeInsets.zero,
                              margin: EdgeInsets.zero,
                              color: theme.colorScheme.surface,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: 150),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TabBar(
                                      controller: _tabController,
                                      isScrollable: true,
                                      indicatorColor: mainColor,
                                      tabs: <Widget>[
                                        Tab(icon: Icon(Icons.person_add_alt_1), text: str.newUser),
                                        Tab(icon: Icon(Icons.person), text: str.existingUser),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: TextFormField(
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: str.enter_your_email_address,
                          labelText: str.email,
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? false) {
                            return str.this_field_required;
                          }
                          return !EmailValidator.validate(value ?? '') ? str.emailValidationFail : null;
                        },
                        onSaved: (String? value) {
                          submittedValue = value?.trim().toLowerCase();
                        },
                        onFieldSubmitted: (value) async {
                          if (_formKey.currentState!.validate()) {
                            await registerOrSignin(value);
                          }
                        },
                        autofocus: false,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.none,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: FilledButton(
                        onPressed: onSubmitButton,
                        child: Text(newUser == true ? str.register : str.signin),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Privacy note: Your email address does not leave your device when you press "${newUser ? str.register : str.signin}"',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          height: 1.4,
                          fontSize: (theme.textTheme.titleMedium!.fontSize ?? 14) - 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Alternatively, you can use the app for free on this device',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                height: 1.4,
                fontSize: (theme.textTheme.titleMedium!.fontSize ?? 14) - 2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 50.0),
            child: FilledButton(onPressed: widget.onLocalOnlyRequested, child: const Text('Use for free')),
          ),
        ],
      ),
    );
  }
}
