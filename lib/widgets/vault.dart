import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:keevault/config/app.dart';
import 'package:keevault/config/routes.dart';
import 'package:keevault/cubit/account_cubit.dart';
import 'package:keevault/cubit/app_settings_cubit.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/cubit/filter_cubit.dart';
import 'package:keevault/password_mismatch_recovery_situation.dart';
import 'package:keevault/vault_backend/exceptions.dart';
import 'package:keevault/widgets/vault_password_credentials.dart';

import '../config/platform.dart';
import '../cubit/vault_cubit.dart';
import '../generated/l10n.dart';
import '../logging/logger.dart';
import 'coloured_safe_area_widget.dart';
import 'autofill_save.dart';
import 'bottom.dart';
import 'entry_filters.dart';
import 'entry_list.dart';
import 'intro_vault_summary.dart';
import 'new_entry_button.dart';
import 'vault_top.dart';

class VaultWidget extends StatefulWidget {
  const VaultWidget({super.key});

  @override
  State<VaultWidget> createState() => _VaultWidgetState();
}

class _VaultWidgetState extends State<VaultWidget> with WidgetsBindingObserver {
  late Timer _timer;

  Future<void> _refresh() async {
    final user = BlocProvider.of<AccountCubit>(context).currentUserIfKnown;
    if (user == null) {
      return;
    }
    final AutofillState autofillState = BlocProvider.of<AutofillCubit>(context).state;
    if (autofillState is AutofillModeActive) {
      //TODO: Maybe proceed if AutofillSaved? Or clear that state after applifecyclestate resumes? Until then, ...................
      l.t('Skip refresh due to state: ${autofillState.runtimeType}');
      return;
    }
    await BlocProvider.of<VaultCubit>(context).refresh(user);
  }

  Future<void> _refreshAuthenticate(String password) async {
    final user = BlocProvider.of<AccountCubit>(context).currentUser;
    final VaultState vaultState = BlocProvider.of<VaultCubit>(context).state;
    PasswordMismatchRecoverySituation recovery = PasswordMismatchRecoverySituation.none;
    if (vaultState is VaultRefreshCredentialsRequired) {
      recovery = vaultState.recovery;
    }
    await BlocProvider.of<VaultCubit>(context).refresh(user, overridePasswordRemote: password, recovery: recovery);
  }

  Future<void> _uploadAuthenticate(String password) async {
    final user = BlocProvider.of<AccountCubit>(context).currentUser;
    final VaultState vaultState = BlocProvider.of<VaultCubit>(context).state;
    if (vaultState is VaultUploadCredentialsRequired) {
      await BlocProvider.of<VaultCubit>(
        context,
      ).upload(user, vaultState.vault, overridePasswordRemote: password, recovery: vaultState.recovery);
    }
  }

  @override
  void initState() {
    _timer = Timer.periodic(Duration(minutes: 1), (timer) async {
      await _refresh();
    });

    WidgetsBinding.instance.addObserver(this);
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) async => await autofillMergeIfRequired(onlyIfAttemptAlreadyDue: true),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      unawaited(autofillMergeIfRequired(onlyIfAttemptAlreadyDue: false));
    }
  }

  Future<void> autofillMergeIfRequired({required bool onlyIfAttemptAlreadyDue}) async {
    if (KeeVaultPlatform.isIOS) {
      l.t('checking if autofill merge required. $onlyIfAttemptAlreadyDue');
      final user = BlocProvider.of<AccountCubit>(context).currentUserIfKnown;
      await BlocProvider.of<VaultCubit>(context).autofillMerge(user, onlyIfAttemptAlreadyDue: onlyIfAttemptAlreadyDue);
    }
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    super.dispose();
  }

  Widget buildAuthRequest(VaultState state, S str) {
    if (state is VaultUploadCredentialsRequired) {
      return VaultPasswordCredentialsWidget(
        reason: str.reenterYourPassword,
        onSubmit: _uploadAuthenticate,
        showError: state.causedByInteraction,
      );
    } else if (state is VaultRefreshCredentialsRequired) {
      return VaultPasswordCredentialsWidget(
        reason: str.reenterYourPassword,
        onSubmit: _refreshAuthenticate,
        showError: state.causedByInteraction,
      );
    }
    throw KeeException('Invalid buildAuthRequest state: ${state.runtimeType}');
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return BlocConsumer<AutofillCubit, AutofillState>(
      builder: (context, autofillState) {
        return BlocConsumer<VaultCubit, VaultState>(
          buildWhen: (previous, current) => current is VaultLoaded,
          builder: (context, state) {
            if (state is VaultRefreshCredentialsRequired || state is VaultUploadCredentialsRequired) {
              return ColouredSafeArea(
                child: Scaffold(
                  appBar: AppBar(
                    title: Image(
                      image: AssetImage('assets/vault.png'),
                      excludeFromSemantics: true,
                      height: 48,
                      color: theme.colorScheme.primary,
                    ),
                    centerTitle: true,
                    toolbarHeight: 80,
                  ),
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[buildAuthRequest(state, str)],
                    ),
                  ),
                ),
              );
            } else if (state is VaultLoaded) {
              if (autofillState is AutofillSaving) {
                return AutofillSaveWidget();
              } else {
                return Scaffold(
                  appBar: vaultTopBarWidget(context),
                  body: _MainLayer(child: EntryListWidget()),
                  drawer: Drawer(
                    width: MediaQuery.of(context).size.width * 0.88,
                    child: SafeArea(child: EntryFilters()),
                  ),
                  bottomNavigationBar: BottomBarWidget(() => toggleBottomDrawerVisibility(context)),
                  floatingActionButton: NewEntryButton(currentFile: state.vault.files.current),
                  floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
                );
              }
            } else {
              return Text('Invalid Vault state');
            }
          },
          listener: (context, state) async {
            if (state is! VaultLoaded && state is! VaultImporting) {
              BlocProvider.of<FilterCubit>(context).reset();
              await AppConfig.router.navigateTo(context, Routes.root, clearStack: true);
            } else if (state is VaultBackgroundError) {
              if (state.toast) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.message), duration: Duration(seconds: 8)));
              }
            }
          },
        );
      },
      listener: (BuildContext context, AutofillState state) {
        if (state is AutofillSaving) {
          l.d('Popping until top level reached');
          AppConfig.navigatorKey.currentState?.popUntil((r) {
            return r.isFirst;
          });
        }
      },
    );
  }
}

class _MainLayer extends StatelessWidget {
  const _MainLayer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FilterCubit, FilterState>(
      builder: (context, state) {
        return BlocBuilder<AppSettingsCubit, AppSettingsState>(
          builder: (context, appSettingsState) {
            final theme = Theme.of(context);
            final main = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  height: 48.0,
                  alignment: AlignmentDirectional.centerStart,
                  child: DefaultTextStyle(
                    style: TextStyle(color: theme.hintColor),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(_generateTitle(context, state)),
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            );
            return Column(
              children: [
                if (!(appSettingsState as AppSettingsBasic).introShownVaultSummary)
                  IntroVaultSummaryWidget(theme: theme),
                Expanded(child: main),
              ],
            );
          },
        );
      },
    );
  }

  String _generateTitle(BuildContext context, FilterState state) {
    final str = S.of(context);

    if (state is FilterActive) {
      final bool text = state.text.isNotEmpty;
      final bool group = state.groupUuid != state.rootGroupUuid;
      final bool tag = state.tags.isNotEmpty;
      final bool color = state.colors.isNotEmpty;

      if (!text && !group && !tag && !color) {
        return str.showing_all_entries;
      } else {
        final criteria = [
          if (group) str.group,
          if (text) str.text.toLowerCase(),
          if (tag && state.tags.length > 1) str.labels.toLowerCase(),
          if (tag && state.tags.length == 1) str.label.toLowerCase(),
          if (color && state.colors.length > 1) str.colors.toLowerCase(),
          if (color && state.colors.length == 1) str.color.toLowerCase(),
        ];
        return str.filteredByCriteria(
          criteria.length > 2
              ? '${criteria.getRange(0, criteria.length - 1).join(', ')} and ${criteria.last}'
              : criteria.join(' and '),
        );
      }
    }
    return str.loading;
  }
}
