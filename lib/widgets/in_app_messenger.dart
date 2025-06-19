import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/config/platform.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/cubit/interaction_cubit.dart';
import 'package:keevault/widgets/prc_dismiss_dialog.dart';
import 'package:keevault/widgets/prc_signup_prompt_dialog.dart';

import '../config/app.dart';
import '../config/routes.dart';
import '../cubit/account_cubit.dart';
import '../cubit/app_settings_cubit.dart';
import '../generated/l10n.dart';
import '../logging/logger.dart';

enum InAppMessageTrigger { entryChanged, entryUnchanged, vaultSaved }

class InAppMessengerWidget extends InheritedWidget {
  const InAppMessengerWidget({
    super.key,
    required this.appSettingsState,
    required super.child,
    required this.navigatorKey,
  });

  final AppSettingsState appSettingsState;
  final GlobalKey<NavigatorState> navigatorKey;

  static InAppMessengerWidget of(BuildContext context) {
    final InAppMessengerWidget? result = context.dependOnInheritedWidgetOfExactType<InAppMessengerWidget>();
    assert(result != null, 'No InAppMessengerWidget found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(InAppMessengerWidget oldWidget) => false;

  Future<void> showIfAppropriate(InAppMessageTrigger reason) async {
    final context = navigatorKey.currentState!.overlay!.context;
    final interactionCubit = BlocProvider.of<InteractionCubit>(context);
    final potentialMessagesPrioritised = [];
    if (reason == InAppMessageTrigger.entryChanged) {
      potentialMessagesPrioritised.add('iamMakeMoreChangesOrSave');
      potentialMessagesPrioritised.add('iamEmailSignup');
    } else if (reason == InAppMessageTrigger.entryUnchanged) {
      potentialMessagesPrioritised.add('iamAutofillDisabled');
    } else if (reason == InAppMessageTrigger.vaultSaved) {
      potentialMessagesPrioritised.add('iamSavingVault');
    }
    for (var iamName in potentialMessagesPrioritised) {
      final iam = (appSettingsState as AppSettingsBasic).iamFromName(iamName);

      final interactionState = (interactionCubit.state as InteractionBasic);
      final accountCubit = BlocProvider.of<AccountCubit>(context);
      final autofillState = BlocProvider.of<AutofillCubit>(context).state;
      if (!iam.isSuppressed(
        accountCubit,
        (autofillState is! AutofillAvailable || autofillState.enabled),
        interactionState,
      )) {
        ScaffoldMessenger.of(context)
          ..removeCurrentMaterialBanner()
          ..showMaterialBanner(_buildMaterialBanner(iamName, context));
        await BlocProvider.of<AppSettingsCubit>(context).iamDisplayed(iamName);
        // Only show one message per event to avoid overwhelming the user
        break;
      }
    }
  }

  MaterialBanner _buildMaterialBanner(String name, BuildContext context) {
    switch (name) {
      case 'iamEmailSignup':
        return _buildMaterialBannerEmailSignup(context);
      case 'iamMakeMoreChangesOrSave':
        return _buildMaterialBannerMakeMoreChangesOrSave(context);
      case 'iamAutofillDisabled':
        return _buildMaterialBannerAutofillDisabled(context);
      case 'iamSavingVault':
        return _buildMaterialBannerSavingVault(context);
    }
    throw Exception('Unknown banner type name $name');
  }

  MaterialBanner _buildMaterialBannerEmailSignup(BuildContext context) {
    final str = S.of(context);

    return _buildBanner(context, Text(str.bannerMsg1TitleB), <Widget>[
      TextButton(
        onPressed: () async {
          final appSettings = BlocProvider.of<AppSettingsCubit>(context);
          final sm = ScaffoldMessenger.of(context);
          final completed = await PRCSignupPromptDialog().show(context);
          if (completed ?? false) {
            await appSettings.iamEmailSignupSuppressUntil(DateTime(2122));
            sm.hideCurrentMaterialBanner();
          }
        },
        child: Text(str.alertYesPlease.toUpperCase()),
      ),
      TextButton(
        onPressed: () async {
          final appSettings = BlocProvider.of<AppSettingsCubit>(context);
          final sm = ScaffoldMessenger.of(context);
          final waitForDays = await BannerDismissDialog().show(context) ?? -1;
          l.d('Will wait for $waitForDays days until reshowing this message');
          await appSettings.iamEmailSignupSuppressUntil(
            waitForDays == -1 ? DateTime(2122) : DateTime.now().toUtc().add(Duration(days: waitForDays)),
          );
          sm.hideCurrentMaterialBanner();
        },
        child: Text(str.alertNo.toUpperCase()),
      ),
    ], null);
  }

  MaterialBanner _buildMaterialBannerMakeMoreChangesOrSave(BuildContext context) {
    final str = S.of(context);
    return _buildBanner(
      context,
      Column(
        children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(str.makeMoreChangesOrSave1)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(str.makeMoreChangesOrSave2)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(str.makeMoreChangesOrSave3)),
        ],
      ),
      <Widget>[
        TextButton(
          onPressed: () async {
            final sm = ScaffoldMessenger.of(context);
            await BlocProvider.of<AppSettingsCubit>(context).iamMakeMoreChangesOrSaveSuppressUntil(DateTime(2122));
            sm.hideCurrentMaterialBanner();
          },
          child: Text(str.gotIt.toUpperCase()),
        ),
      ],
      null,
    );
  }

  MaterialBanner _buildBanner(BuildContext context, content, actions, leading) {
    final theme = Theme.of(context);
    final shadowColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black;
    final dividerColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black;
    final backgroundColor = theme.brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade300;
    return MaterialBanner(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      margin: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      elevation: 3,
      leading: leading,
      forceActionsBelow: true,
      content: content,
      actions: actions,
      shadowColor: shadowColor,
      dividerColor: dividerColor,
      backgroundColor: backgroundColor,
    );
  }

  MaterialBanner _buildMaterialBannerAutofillDisabled(BuildContext context) {
    final str = S.of(context);
    return _buildBanner(context, Text(str.bannerMsgAutofillDisabled), <Widget>[
      TextButton(
        onPressed: () async {
          final sm = ScaffoldMessenger.of(context);
          if (KeeVaultPlatform.isAndroid) {
            await BlocProvider.of<AutofillCubit>(context).requestEnable();
            sm.hideCurrentMaterialBanner();
          } else if (KeeVaultPlatform.isIOS) {
            sm.hideCurrentMaterialBanner();
            await AppConfig.router.navigateTo(context, Routes.settings);
          }
        },
        child: Text(str.enableAutofill.toUpperCase()),
      ),
      TextButton(
        onPressed: () async {
          final sm = ScaffoldMessenger.of(context);
          final appSettings = BlocProvider.of<AppSettingsCubit>(context);
          final waitForDays = await BannerDismissDialog().show(context) ?? -1;
          l.d('Will wait for $waitForDays days until reshowing this message');
          await appSettings.iamAutofillDisabledSuppressUntil(
            waitForDays == -1 ? DateTime(2122) : DateTime.now().toUtc().add(Duration(days: waitForDays)),
          );
          sm.hideCurrentMaterialBanner();
        },
        child: Text(str.alertNo.toUpperCase()),
      ),
    ], null);
  }

  MaterialBanner _buildMaterialBannerSavingVault(BuildContext context) {
    final str = S.of(context);
    return _buildBanner(
      context,
      Column(
        children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(str.bannerMsgSaving1)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(str.bannerMsgSaving2)),
        ],
      ),
      <Widget>[
        TextButton(
          onPressed: () async {
            final sm = ScaffoldMessenger.of(context);
            await BlocProvider.of<AppSettingsCubit>(context).iamSavingVaultSuppressUntil(DateTime(2122));
            sm.hideCurrentMaterialBanner();
          },
          child: Text(str.gotIt.toUpperCase()),
        ),
      ],
      Icon(Icons.lock),
    );
  }
}
