import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/cubit/interaction_cubit.dart';
import 'package:keevault/widgets/prc_dismiss_dialog.dart';
import 'package:keevault/widgets/prc_signup_prompt_dialog.dart';

import '../cubit/account_cubit.dart';
import '../cubit/app_settings_cubit.dart';
import '../generated/l10n.dart';
import '../logging/logger.dart';

enum InAppMessageTrigger { entryChanged, entryUnchanged, vaultSaved }

class InAppMessengerWidget extends InheritedWidget {
  const InAppMessengerWidget({
    Key? key,
    required this.appSettingsState,
    required Widget child,
    required this.navigatorKey,
  }) : super(key: key, child: child);

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
      if (!iam.isSuppressed(accountCubit, BlocProvider.of<AutofillCubit>(context).state, interactionState)) {
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
    return MaterialBanner(
      padding: EdgeInsets.all(20),
      forceActionsBelow: true,
      content: Text(str.bannerMsg1TitleB),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            final completed = await PRCSignupPromptDialog().show(context);
            if (completed ?? false) {
              await BlocProvider.of<AppSettingsCubit>(context).iamEmailSignupSuppressUntil(DateTime(2122));
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            }
          },
          child: Text(str.alertYesPlease.toUpperCase()),
        ),
        TextButton(
          onPressed: () async {
            final waitForDays = await BannerDismissDialog().show(context) ?? -1;
            l.d('Will wait for $waitForDays days until reshowing this message');
            await BlocProvider.of<AppSettingsCubit>(context).iamEmailSignupSuppressUntil(
                waitForDays == -1 ? DateTime(2122) : DateTime.now().toUtc().add(Duration(days: waitForDays)));
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
          },
          child: Text(str.alertNo.toUpperCase()),
        ),
      ],
    );
  }

  MaterialBanner _buildMaterialBannerMakeMoreChangesOrSave(BuildContext context) {
    final str = S.of(context);
    return MaterialBanner(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      forceActionsBelow: true,
      content: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(str.makeMoreChangesOrSave1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(str.makeMoreChangesOrSave2),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(str.makeMoreChangesOrSave3),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            await BlocProvider.of<AppSettingsCubit>(context).iamMakeMoreChangesOrSaveSuppressUntil(DateTime(2122));
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
          },
          child: Text(str.gotIt.toUpperCase()),
        ),
      ],
    );
  }

  MaterialBanner _buildMaterialBannerAutofillDisabled(BuildContext context) {
    final str = S.of(context);
    return MaterialBanner(
      padding: EdgeInsets.all(20),
      forceActionsBelow: true,
      content: Text(str.bannerMsgAutofillDisabled),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            await BlocProvider.of<AutofillCubit>(context).requestEnable();
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
          },
          child: Text(str.enableAutofill.toUpperCase()),
        ),
        TextButton(
          onPressed: () async {
            final waitForDays = await BannerDismissDialog().show(context) ?? -1;
            l.d('Will wait for $waitForDays days until reshowing this message');
            await BlocProvider.of<AppSettingsCubit>(context).iamAutofillDisabledSuppressUntil(
                waitForDays == -1 ? DateTime(2122) : DateTime.now().toUtc().add(Duration(days: waitForDays)));
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
          },
          child: Text(str.alertNo.toUpperCase()),
        ),
      ],
    );
  }

  MaterialBanner _buildMaterialBannerSavingVault(BuildContext context) {
    final str = S.of(context);
    return MaterialBanner(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      leading: Icon(Icons.lock),
      forceActionsBelow: true,
      content: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(str.bannerMsgSaving1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(str.bannerMsgSaving2),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            await BlocProvider.of<AppSettingsCubit>(context).iamSavingVaultSuppressUntil(DateTime(2122));
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
          },
          child: Text(str.gotIt.toUpperCase()),
        ),
      ],
    );
  }
}
