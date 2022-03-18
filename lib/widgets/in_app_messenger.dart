import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/cubit/interaction_cubit.dart';
import 'package:keevault/widgets/prc_dismiss_dialog.dart';
import 'package:keevault/widgets/prc_signup_prompt_dialog.dart';

import '../cubit/account_cubit.dart';
import '../cubit/app_settings_cubit.dart';
import '../generated/l10n.dart';
import '../logging/logger.dart';

class InAppMessengerWidget extends InheritedWidget {
  const InAppMessengerWidget({
    Key? key,
    required this.appSettingsState,
    required Widget child,
  }) : super(key: key, child: child);

  final AppSettingsState appSettingsState;

  static InAppMessengerWidget of(BuildContext context) {
    final InAppMessengerWidget? result = context.dependOnInheritedWidgetOfExactType<InAppMessengerWidget>();
    assert(result != null, 'No InAppMessengerWidget found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(InAppMessengerWidget oldWidget) => false;

  Future<void> showIfAppropriate(BuildContext context) async {
    final interactionCubit = BlocProvider.of<InteractionCubit>(context);
    final iam = (appSettingsState as AppSettingsBasic).iamEmailSignup;
    final interactionState = (interactionCubit.state as InteractionBasic);
    final accountCubit = BlocProvider.of<AccountCubit>(context);
    //TODO:f: more general logic for other messages
    if (accountCubit.currentUserIfKnown != null && !iam.isSuppressed(interactionState)) {
      ScaffoldMessenger.of(context)
        ..removeCurrentMaterialBanner()
        ..showMaterialBanner(_buildMaterialBanner(context));
      await BlocProvider.of<AppSettingsCubit>(context).iamEmailSignupDisplayed();
    }
  }

  MaterialBanner _buildMaterialBanner(BuildContext context) {
    final str = S.of(context);
    return MaterialBanner(
      padding: EdgeInsets.all(20),
      content: Text(str.bannerMsg1TitleB),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            final completed = await PRCSignupPromptDialog().show(context);
            if (completed ?? false) {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            }
          },
          child: Text(str.alertYesPlease.toUpperCase()),
        ),
        TextButton(
          onPressed: () async {
            final waitForDays = await PRCDismissDialog().show(context) ?? -1;
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
}
