import 'package:biometric_storage/biometric_storage.dart';
import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:keevault/config/app.dart';
import 'package:keevault/config/environment_config.dart';
import 'package:keevault/config/routes.dart';
import 'package:keevault/cubit/account_cubit.dart';
import 'package:keevault/cubit/app_settings_cubit.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/cubit/vault_cubit.dart';
import 'package:matomo/matomo.dart';
import '../generated/l10n.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dialog_utils.dart';

class SettingsWidget extends TraceableStatefulWidget {
  const SettingsWidget({
    Key? key,
  }) : super(key: key);

  @override
  _SettingsWidgetState createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  @override
  Widget build(BuildContext context) {
    final str = S.of(context);

    return BlocBuilder<AccountCubit, AccountState>(builder: (context, accountState) {
      final accountChildren = [];
      if (accountState is AccountChosen) {
        final userEmail = accountState.user.email;
        if (userEmail != null) {
          accountChildren.add(SettingsContainer(
            children: [
              Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                  child: Column(children: [
                    Text(str.useWebAppForOtherSettings),
                    TextButton.icon(
                      icon: Text(str.openWebApp),
                      label: Icon(Icons.open_in_new),
                      onPressed: () async {
                        DialogUtils.openUrl(EnvironmentConfig.webUrl + '/#pfEmail=$userEmail,dest=signin');
                      },
                    ),
                  ]),
                ),
                Divider(
                  height: 0.0,
                ),
              ])
            ],
          ));

          accountChildren.add(SettingsContainer(
            children: [
              Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                  child: Column(
                    children: [
                      Text(str.manageAccountSettingsDetail),
                      TextButton.icon(
                        icon: Text(str.manageAccount),
                        label: Icon(Icons.open_in_new),
                        onPressed: () async {
                          DialogUtils.openUrl(EnvironmentConfig.webUrl + '/#pfEmail=$userEmail,dest=manageAccount');
                        },
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 0.0,
                ),
              ])
            ],
          ));
        }
      }
      return BlocBuilder<AutofillCubit, AutofillState>(builder: (context, autofillState) {
        return SettingsScreen(
          title: str.settings,
          children: [
            SettingsGroup(
              children: [
                RadioSettingsTile<String>(
                  title: str.setGenTheme,
                  showTitles: false,
                  settingKey: 'theme',
                  values: <String, String>{
                    'sys': str.setGenTitlebarStyleDefault,
                    'lt': str.setGenThemeLt,
                    'dk': str.setGenThemeDk,
                  },
                  selected: 'sys',
                  onChange: (String value) {
                    BlocProvider.of<AppSettingsCubit>(context).changeTheme(value);
                  },
                ),
              ],
              title: str.setGenTheme,
            ),
            SettingsGroup(children: [
              Visibility(
                visible: autofillState is AutofillAvailable,
                child: SettingsContainer(
                  children: [
                    AutofillStatusWidget(isEnabled: (autofillState as AutofillAvailable).enabled),
                  ],
                ),
              ),
              BiometricSettingWidget(),
            ], title: str.deviceSettings),
            SettingsGroup(
              children: [
                SimpleSettingsTile(
                  title: str.genPsTitle,
                  subtitle: str.managePasswordPresets,
                  onTap: () => AppConfig.router.navigateTo(
                    context,
                    Routes.passwordPresetManager,
                    transition: TransitionType.inFromRight,
                  ),
                ),
                SwitchSettingsTile(
                  settingKey: 'expandGroups',
                  title: str.setGenShowSubgroups,
                  defaultValue: true,
                ),
                //TODO:f: Need to store group in DB so this should really be a DB-specific setting.
                // SwitchSettingsTile(
                //   settingKey: 'rememberFilterGroup',
                //   title: str.rememberFilterGroup,
                //   defaultValue: false,
                // ),
                ...accountChildren,
              ],
              title: str.menuSetGeneral,
            ),
          ],
        );
      });
    });
  }
}

class BiometricSettingWidget extends StatefulWidget {
  const BiometricSettingWidget({Key? key}) : super(key: key);

  @override
  _BiometricSettingWidgetState createState() => _BiometricSettingWidgetState();
}

class _BiometricSettingWidgetState extends State<BiometricSettingWidget> {
  bool _isEnabled = false;
  @override
  void initState() {
    super.initState();
    _initBiometricStorageStatus();
  }

  Future<void> _initBiometricStorageStatus() async {
    final enabled = (await BiometricStorage().canAuthenticate()) == CanAuthenticateResponse.success;
    setState(() {
      _isEnabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return SwitchSettingsTile(
      settingKey: 'biometrics-enabled',
      title: str.biometricSignIn,
      onChange: (value) {
        //TODO:f: Can we prompt immediately to get the relevant credentials stored?
        if (!value) {
          BlocProvider.of<VaultCubit>(context).disableQuickUnlock();
        }
      },
      enabled: _isEnabled,
      defaultValue: true,
      childrenIfEnabled: [
        TextInputSettingsTile(
          title: str.automaticallySignInFor,
          settingKey: 'authGracePeriod',
          initialValue: '60',
          keyboardType: TextInputType.number,
          validator: (String? gracePeriod) {
            if (gracePeriod != null) {
              final number = int.tryParse(gracePeriod);
              if (number != null && number >= 1 && number <= 3600) {
                return null;
              }
            }
            return str.enterNumberBetweenXAndY(1, 3600);
          },
          onChange: (_) => BlocProvider.of<VaultCubit>(context).disableQuickUnlock(),
          autoValidateMode: AutovalidateMode.always,
        ),
        TextInputSettingsTile(
          title: str.requireFullPasswordEvery,
          settingKey: 'requireFullPasswordPeriod',
          initialValue: '60',
          keyboardType: TextInputType.number,
          validator: (String? requireFullPasswordPeriod) {
            if (requireFullPasswordPeriod != null) {
              final number = int.tryParse(requireFullPasswordPeriod);
              if (number != null && number >= 1 && number <= 180) {
                return null;
              }
            }
            return str.enterNumberBetweenXAndY(1, 180);
          },
          onChange: (_) => BlocProvider.of<VaultCubit>(context).disableQuickUnlock(),
          autoValidateMode: AutovalidateMode.always,
        ),
      ],
    );
  }
}

class AutofillStatusWidget extends StatefulWidget {
  final bool isEnabled;
  const AutofillStatusWidget({Key? key, required this.isEnabled}) : super(key: key);

  @override
  _AutofillStatusWidgetState createState() => _AutofillStatusWidgetState();
}

class _AutofillStatusWidgetState extends State<AutofillStatusWidget> {
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
    final str = S.of(context);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: Column(children: [
          Visibility(
            visible: widget.isEnabled,
            child: Text(
              str.autofillEnabled,
            ),
            replacement: Text(str.enableAutofillRequired(_packageInfo.appName)),
          ),
          Visibility(
            visible: !widget.isEnabled,
            child: ElevatedButton(
              child: Text(str.enableAutofill),
              onPressed: () async {
                await BlocProvider.of<AutofillCubit>(context).requestEnable();
              },
            ),
          ),
          Visibility(
            visible: widget.isEnabled,
            child: SwitchSettingsTile(
              settingKey: 'autofillServiceEnableSaving',
              title: str.offerToSave,
              defaultValue: true,
              onChange: (value) async {
                // We assume the autofill preference's SharedPreferences feature
                // is in sync to begin with and always specify what the user has
                // requested from our own preference so in the worst case, the
                // user will have to toggle the switch a couple of times to
                // resync and fix any broken behaviour.
                await BlocProvider.of<AutofillCubit>(context).setSavingPreference(value);
              },
            ),
          ),
        ]),
      ),
      Divider(
        height: 0.0,
      ),
    ]);
  }
}
