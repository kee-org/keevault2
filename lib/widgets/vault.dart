import 'dart:async';

import 'package:animate_icons/animate_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:keevault/config/app.dart';
import 'package:keevault/config/routes.dart';
import 'package:keevault/cubit/account_cubit.dart';
import 'package:keevault/cubit/app_settings_cubit.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/cubit/filter_cubit.dart';
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
  const VaultWidget({
    Key? key,
  }) : super(key: key);

  @override
  State<VaultWidget> createState() => _VaultWidgetState();
}

class _VaultWidgetState extends State<VaultWidget> with WidgetsBindingObserver {
  late Timer _timer;

  Future<void> _refresh() async {
    final user = BlocProvider.of<AccountCubit>(context).currentUserIfKnown;
    final AutofillState autofillState = BlocProvider.of<AutofillCubit>(context).state;
    if (autofillState is AutofillModeActive || user == null) {
      return;
    }
    await BlocProvider.of<VaultCubit>(context).refresh(user);
  }

  Future<void> _refreshAuthenticate(String password) async {
    final user = BlocProvider.of<AccountCubit>(context).currentUser;
    await BlocProvider.of<VaultCubit>(context).refresh(user, overridePassword: password);
  }

  Future<void> _uploadAuthenticate(String password) async {
    final user = BlocProvider.of<AccountCubit>(context).currentUser;
    final VaultState vaultState = BlocProvider.of<VaultCubit>(context).state;
    if (vaultState is VaultUploadCredentialsRequired) {
      await BlocProvider.of<VaultCubit>(context).upload(user, vaultState.vault, overridePassword: password);
    }
  }

  @override
  void initState() {
    _timer = Timer.periodic(Duration(minutes: 1), (timer) async {
      await _refresh();
    });

    WidgetsBinding.instance.addObserver(this);
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) async => await autofillMergeIfRequired(onlyIfAttemptAlreadyDue: true));
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
      l.v('checking if autofill merge required. $onlyIfAttemptAlreadyDue');
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
                        color: Colors.white,
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
                  return Backdrop(
                      frontLayer: EntryListWidget(),
                      backLayer: Container(
                        color: Theme.of(context).cardColor,
                        child: Theme(
                          data: Theme.of(context),
                          child: EntryFilters(),
                        ),
                      ),
                      frontTitle: Text('front title'));
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(state.message),
                    duration: Duration(seconds: 8),
                  ));
                }
              }
            });
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

const double _kFlingVelocity = 2.0;

class _FrontLayer extends StatelessWidget {
  const _FrontLayer({
    Key? key,
    this.onTap,
    required this.child,
  }) : super(key: key);

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FilterCubit, FilterState>(
      builder: (context, state) {
        return BlocBuilder<AppSettingsCubit, AppSettingsState>(
          builder: (context, appSettingsState) {
            final theme = Theme.of(context);
            final main = Material(
              elevation: 10.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24.0), topRight: Radius.circular(24.0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: Container(
                        height: 48.0,
                        alignment: AlignmentDirectional.centerStart,
                        child: DefaultTextStyle(
                          style: TextStyle(color: theme.hintColor),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Text(_generateTitle(context, state)),
                          ),
                        )),
                  ),
                  Expanded(
                    child: child,
                  ),
                ],
              ),
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
        return str.filteredByCriteria(criteria.length > 2
            ? '${criteria.getRange(0, criteria.length - 1).join(', ')} and ${criteria.last}'
            : criteria.join(' and '));
      }
    }
    return str.loading;
  }
}

// Builds a Backdrop.
//
// A Backdrop widget has two layers, front and back. The front layer is shown
// by default, and slides down to show the back layer.
class Backdrop extends StatefulWidget {
  final Widget frontLayer;
  final Widget backLayer;
  final Widget frontTitle;

  const Backdrop({
    Key? key,
    required this.frontLayer,
    required this.backLayer,
    required this.frontTitle,
  }) : super(key: key);

  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop> with SingleTickerProviderStateMixin {
  final GlobalKey _backdropKey = GlobalKey(debugLabel: 'Backdrop');
  late AnimationController _controller;
  late AnimateIconController _animatedIconController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300),
      value: 1.0,
      vsync: this,
    );
    _animatedIconController = AnimateIconController();
  }

  @override
  void didUpdateWidget(Backdrop old) {
    super.didUpdateWidget(old);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _frontLayerVisible {
    final AnimationStatus status = _controller.status;
    return status == AnimationStatus.completed || status == AnimationStatus.forward;
  }

  void _toggleBackdropLayerVisibility() {
    if (_frontLayerVisible) {
      _removeKeyboardFocus();
      _animatedIconController.animateToEnd();
    } else {
      _animatedIconController.animateToStart();
    }
    _controller.fling(velocity: _frontLayerVisible ? -_kFlingVelocity : _kFlingVelocity);
  }

  Widget _buildStack(BuildContext context, BoxConstraints constraints) {
    final MediaQueryData mq = MediaQuery.of(context);
    const double layerTitleHeight = 48.0;
    // bottom app bar height is increased by viewPadding and zero when keyboard is showing
    //final double bottomAppBarHeight = mq.viewInsets.bottom <= 0.0 ? mq.padding.bottom : 0;
    final double bottomAppBarHeight = mq.padding.bottom;
    final Size layerSize = constraints.biggest;
    final double layerTop = layerSize.height - layerTitleHeight - bottomAppBarHeight;

    Animation<RelativeRect> layerAnimation = RelativeRectTween(
      begin: RelativeRect.fromLTRB(0.0, layerTop, 0.0, 0),
      end: RelativeRect.fromLTRB(0.0, 0.0, 0.0, 0.0),
    ).animate(_controller.view);

    return Stack(
      key: _backdropKey,
      children: <Widget>[
        ExcludeSemantics(
          excluding: _frontLayerVisible,
          child: widget.backLayer,
        ),
        PositionedTransition(
          rect: layerAnimation,
          child: _FrontLayer(
            onTap: _toggleBackdropLayerVisibility,
            child: widget.frontLayer,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var appBar = vaultTopBarWidget(context, _animatedIconController, _controller, _toggleBackdropLayerVisibility,
        Theme.of(context).primaryIconTheme.color!);
    return BlocConsumer<VaultCubit, VaultState>(
      listener: (context, state) {},
      builder: (context, state) {
        return ColouredSafeArea(
          child: Scaffold(
            appBar: appBar,
            body: LayoutBuilder(
              builder: _buildStack,
            ),
            extendBody: true,
            bottomNavigationBar: BottomBarWidget(() => toggleBottomDrawerVisibility(context)),
            floatingActionButton: NewEntryButton(currentFile: (state as VaultLoaded).vault.files.current),
            floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
          ),
        );
      },
      // Sometimes we build this before navigation resulting from change of state
      // to VaultLocalFileCredentialsRequired has occurred
      buildWhen: (previous, current) => current is VaultLoaded,
    );
  }

  _removeKeyboardFocus() {
    FocusScope.of(context).unfocus();
  }
}
