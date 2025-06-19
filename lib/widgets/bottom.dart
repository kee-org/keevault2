import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/config/app.dart';
import 'package:keevault/config/routes.dart';
import 'package:keevault/cubit/account_cubit.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/cubit/vault_cubit.dart';
import 'package:keevault/vault_backend/user.dart';
import '../config/environment_config.dart';
import '../config/platform.dart';
import '../cubit/interaction_cubit.dart';
import '../generated/l10n.dart';
import 'dialog_utils.dart';
import 'in_app_messenger.dart';
import 'vault_drawer.dart';

class BottomDrawerWidget extends StatelessWidget {
  const BottomDrawerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, accountState) {
        User? user = (accountState is AccountChosen) ? accountState.user : null;
        final emailAddress = user?.email ?? str.notSignedIn;
        return BlocBuilder<VaultCubit, VaultState>(
          builder: (context, state) {
            return BlocBuilder<AutofillCubit, AutofillState>(
              builder: (context, autoFillState) {
                return ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.all(8),
                  children: <Widget>[
                    Image(image: AssetImage('assets/vault.png'), excludeFromSemantics: true, height: 32),
                    Divider(),
                    if (state is VaultLoaded && !autofillSimpleUIMode(autoFillState)) VaultDrawerWidget(),
                    if (state is VaultLoaded && !autofillSimpleUIMode(autoFillState)) Divider(),
                    AccountDrawerWidget(emailAddress: emailAddress, user: user, str: str),
                    Divider(),
                    // Maybe small chance of context being lost in between navigator pop and next navigation request?
                    // Hasn't happened yet and may not be possible but if mysterious WTF errors are thrown on navigation
                    // on some devices, could look there as a starting point.
                    if (state is VaultLoaded && !autofillSimpleUIMode(autoFillState))
                      ListTile(
                        leading: Icon(Icons.flash_on),
                        title: Text(str.generateSinglePassword),
                        onTap: () async {
                          Navigator.pop(context);
                          await AppConfig.router.navigateTo(context, Routes.passwordGenerator);
                        },
                      ),
                    if (state is VaultLoaded && !autofillSimpleUIMode(autoFillState))
                      ListTile(
                        leading: Icon(Icons.swap_horiz),
                        title: Text(str.importExport),
                        onTap: () async {
                          Navigator.pop(context);
                          await AppConfig.router.navigateTo(context, Routes.importExport);
                        },
                      ),
                    if (state is VaultLoaded && !autofillSimpleUIMode(autoFillState))
                      ListTile(
                        leading: Icon(Icons.settings),
                        title: Text(str.settings),
                        onTap: () async {
                          Navigator.pop(context);
                          await AppConfig.router.navigateTo(context, Routes.settings);
                        },
                      ),
                    ListTile(
                      leading: Icon(Icons.help),
                      title: Text(str.help),
                      onTap: () async {
                        Navigator.pop(context);
                        await AppConfig.router.navigateTo(context, Routes.help);
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

bool autofillSimpleUIMode(AutofillState autoFillState) {
  return autoFillState is AutofillSaving || autoFillState is AutofillRequested;
}

class AccountDrawerWidget extends StatelessWidget {
  const AccountDrawerWidget({super.key, required this.emailAddress, required this.user, required this.str});

  final String emailAddress;
  final User? user;
  final S str;

  Future<void> _forgetUser(BuildContext context) async {
    await BlocProvider.of<AccountCubit>(context).forgetUser(BlocProvider.of<VaultCubit>(context).signout);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VaultCubit, VaultState>(
      builder: (context, state) {
        return BlocBuilder<AutofillCubit, AutofillState>(
          builder: (context, autoFillState) {
            final registrationEnabled =
                (EnvironmentConfig.iapGooglePlay && KeeVaultPlatform.isAndroid) ||
                (EnvironmentConfig.iapAppleAppStore && KeeVaultPlatform.isIOS);
            final theme = Theme.of(context);
            final headerColor = theme.brightness == Brightness.light
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface;
            final accountActionSection = (user?.email != null)
                ? ExpansionTile(
                    initiallyExpanded: state is! VaultLoaded,
                    leading: Icon(Icons.person),
                    title: Text(emailAddress),
                    textColor: headerColor,
                    iconColor: headerColor,
                    children: [
                      OverflowBar(
                        alignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _forgetUser(context);
                            },
                            child: Text(str.signout.toUpperCase()),
                          ),
                        ],
                      ),
                    ],
                  )
                : Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 1,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            'Use your Vault on multiple devices with a Kee Vault account',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        OverflowBar(
                          alignment: MainAxisAlignment.center,
                          children: [
                            FilledButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _forgetUser(context);
                              },
                              child: Text('Sign in ${registrationEnabled ? 'or Register' : ''}'.toUpperCase()),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
            return Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: (!autofillSimpleUIMode(autoFillState))
                  ? accountActionSection
                  : ListTile(leading: Icon(Icons.person), title: Text(emailAddress)),
            );
          },
        );
      },
    );
  }
}

class BottomBarWidget extends StatelessWidget {
  final void Function() _toggleBottomDrawerVisibility;
  final Widget? centreButton;
  const BottomBarWidget(this._toggleBottomDrawerVisibility, {this.centreButton, super.key});

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return BlocBuilder<EntryCubit, EntryState>(
      builder: (context, state) {
        final vaultCubit = BlocProvider.of<VaultCubit>(context);
        final vaultState = vaultCubit.state;
        VaultLoaded loadedVaultState;
        if (vaultState is VaultLoaded) {
          loadedVaultState = vaultState;
        } else {
          return BottomAppBar(
            //elevation: 11,
            height: 48,
            child: Container(
              // We have to wrap in a Container with transparent color because otherwise taps bubble
              // up to the underlying Stack and entry list items contained within.
              color: Colors.transparent,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.menu),
                    onPressed: _toggleBottomDrawerVisibility,
                    visualDensity: VisualDensity.compact,
                  ),
                  Spacer(),
                ],
              ),
            ),
          );
        }
        final loadedState = state is EntryLoaded ? state : null;
        final bool entryEditing = loadedState != null ? true : false;
        const sipi = SaveInProgressIndicatorWidget();

        return BottomAppBar(
          shape: CircularNotchedRectangle(),
          notchMargin: 4,
          //elevation: 11,
          child: Container(
            // We have to wrap in a Container with transparent color because otherwise taps bubble
            // up to the underlying Stack and entry list items contained within.
            color: Colors.transparent,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.menu),
                  onPressed: _toggleBottomDrawerVisibility,
                  visualDensity: VisualDensity.compact,
                ),
                VaultStatusIconWidget(),
                if (loadedVaultState is VaultSaving || loadedVaultState is VaultUpdatingLocalFromAutofill) sipi,
                if (loadedVaultState is! VaultSaving && loadedVaultState is! VaultUpdatingLocalFromAutofill)
                  SizedBox(width: 40, height: 40),
                centreButton != null
                    ? centreButton!
                    : SaveButtonWidget(
                        title: str.saveVault.toUpperCase(),
                        visible:
                            (!vaultCubit.isAutofilling() &&
                            !entryEditing &&
                            loadedVaultState.vault.files.current.isDirty &&
                            loadedVaultState is! VaultSaving &&
                            loadedVaultState is! VaultUpdatingLocalFromRemote &&
                            loadedVaultState is! VaultUpdatingLocalFromAutofill),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class VaultStatusIconWidget extends StatelessWidget {
  const VaultStatusIconWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return BlocBuilder<VaultCubit, VaultState>(
      builder: (context, state) {
        final icon = _buildIcon(state, str);
        return icon != null
            ? IconButton(
                icon: icon,
                onPressed: () async {
                  await DialogUtils.showSimpleAlertDialog(
                    context,
                    null,
                    _buildDescription(state, str),
                    routeAppend: 'vaultStatusExplanation',
                  );
                },
              )
            : SizedBox();
      },
    );
  }

  Icon? _buildIcon(VaultState state, S str) {
    if (state is VaultUploadCredentialsRequired) {
      return Icon(Icons.error);
    } else if (state is VaultSaving) {
      return null;
    } else if (state is VaultRefreshing) {
      return null;
    } else if (state is VaultBackgroundError) {
      return Icon(Icons.sync_problem);
    } else if (state is VaultLoaded) {
      if (state.vault.hasPendingChanges) {
        return Icon(Icons.sync_lock);
      }
      return null;
    }
    return Icon(Icons.device_unknown);
  }

  String _buildDescription(VaultState state, S str) {
    if (state is VaultUploadCredentialsRequired) {
      return str.vaultStatusDescPasswordChanged;
    } else if (state is VaultBackgroundError) {
      return state.message;
    } else if (state is VaultLoaded) {
      if (state.vault.hasPendingChanges) {
        return str.vaultStatusDescSaveNeeded;
      }
      return str.vaultStatusDescLoaded;
    }
    return str.vaultStatusDescUnknown;
  }
}

class SaveButtonWidget extends StatefulWidget {
  final String title;
  final bool visible;

  const SaveButtonWidget({super.key, required this.title, required this.visible});

  @override
  State<SaveButtonWidget> createState() => _SaveButtonWidgetState();
}

class _SaveButtonWidgetState extends State<SaveButtonWidget> {
  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.visible ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300),
      child: FilledButton(
        onPressed: () async {
          if (!widget.visible) return;
          final iam = InAppMessengerWidget.of(context);
          final vaultCubit = BlocProvider.of<VaultCubit>(context);
          final accCubit = BlocProvider.of<AccountCubit>(context);
          await BlocProvider.of<InteractionCubit>(context).databaseSaved();
          await iam.showIfAppropriate(InAppMessageTrigger.vaultSaved);
          await vaultCubit.save(accCubit.currentUserIfKnown);
        },
        child: Text(widget.title),
      ),
    );
  }
}

class SaveInProgressIndicatorWidget extends StatefulWidget {
  const SaveInProgressIndicatorWidget({super.key});

  @override
  State<SaveInProgressIndicatorWidget> createState() => _SaveInProgressIndicatorWidgetState();
}

class _SaveInProgressIndicatorWidgetState extends State<SaveInProgressIndicatorWidget> with TickerProviderStateMixin {
  final Tween<double> _tween = Tween(begin: 0.66, end: 1);

  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 1000),
    vsync: this,
  )..repeat(reverse: true);
  late final Animation<double> _animation = CurvedAnimation(parent: _controller, curve: Curves.ease);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return Tooltip(
      message: str.saveExplainerAlertTitle,
      child: ScaleTransition(
        scale: _tween.animate(_animation),
        child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.lock)),
      ),
    );
  }
}

void toggleBottomDrawerVisibility(BuildContext context) {
  _removeKeyboardFocus(context);
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(10.0), topRight: Radius.circular(10.0)),
      ),
      builder: (BuildContext context) {
        return BottomDrawerWidget();
      },
    ),
  );
}

_removeKeyboardFocus(BuildContext context) {
  FocusScope.of(context).unfocus();
}
