import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/widgets/prc_privacy_dialog.dart';
import '../config/environment_config.dart';
import '../cubit/app_settings_cubit.dart';
import '../vault_backend/mailer_service.dart';
import 'dialog_utils.dart';
import 'package:keevault/generated/l10n.dart';
import 'package:email_validator/email_validator.dart';
import 'package:keevault/logging/logger.dart';
import 'package:matomo_tracker/matomo_tracker.dart';

class ResetAccountPromptDialog extends StatefulWidget with DialogMixin<bool> {
  const ResetAccountPromptDialog({
    Key? key,
    required this.emailAddress,
  }) : super(key: key);

  final String emailAddress;

  @override
  State<ResetAccountPromptDialog> createState() => _ResetAccountPromptDialogState();

  @override
  String get name => '/dialog/resetAccountPrompt';
}

class _ResetAccountPromptDialogState extends State<ResetAccountPromptDialog> with TraceableClientMixin {
  late TextEditingController _controller;
  late bool loading;
  late bool validationError;
  late bool error;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  String get traceTitle => widget.toStringShort();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.emailAddress);
    loading = false;
    validationError = false;
    error = false;
  }

  Future<void> signup() async {
    final str = S.of(context);
    final navigator = Navigator.of(context);
    final sm = ScaffoldMessenger.of(context);
    final appSettingsCubit = BlocProvider.of<AppSettingsCubit>(context);
    formKey.currentState?.validate();
    if (!EmailValidator.validate(_controller.text)) {
      setState(() {
        validationError = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        formKey.currentState?.validate();
      });
      return;
    } else {
      l.d('signing up supplied email address');
      setState(() {
        loading = true;
        validationError = false;
        error = false;
      });
      final mailerService = MailerService(EnvironmentConfig.stage.toStage(), null);
      final result = await mailerService.signup(_controller.text.toLowerCase());
      if (result) {
        l.d('signup successful');
        navigator.pop(true);
        sm.showSnackBar(SnackBar(content: Text(str.prcRegistrationSuccess)));
        MatomoTracker.instance.trackEvent(eventCategory: 'main', eventName: 'prcSignup', action: 'home');
        await appSettingsCubit.iamEmailSignupSuppressUntil(DateTime(2122));
      } else {
        l.e('signup failed');
        setState(() {
          loading = false;
          error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final str = S.of(context);
    return AlertDialog(
      scrollable: true,
      content: Container(
        constraints: const BoxConstraints(minWidth: 400.0),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(str.resetPasswordInstructions),
              ),
              TextButton.icon(
                icon: Text(str.startAccountReset),
                label: Icon(Icons.open_in_new),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await DialogUtils.openUrl(EnvironmentConfig.webUrl + '/#dest=resetPassword');
                  navigator.pop(true);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(str.prcSignupOrAccountStatusCheck(_controller.text)),
              ),
              Visibility(
                visible: validationError || widget.emailAddress != _controller.text,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: TextFormField(
                    controller: _controller,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: str.enter_your_email_address,
                      helperMaxLines: 1,
                      labelStyle: theme.textTheme.titleMedium!.copyWith(color: theme.colorScheme.tertiary),
                    ),
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    keyboardType: TextInputType.emailAddress,
                    maxLines: 1,
                    onEditingComplete: loading ? null : signup,
                    validator: (val) =>
                        !EmailValidator.validate(val ?? '') ? 'Not a valid email address. Please try again.' : null,
                    style: theme.textTheme.titleMedium!.copyWith(color: theme.colorScheme.tertiary),
                  ),
                ),
              ),
              Visibility(
                visible: error,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(str.prcRegistrationError),
                ),
              ),
              TextButton(
                onPressed: () async => await PrcPrivacyDialog().show(context),
                child: Text(
                  str.privacyStatement,
                  style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.tertiary),
                ),
              ),
              TextButton(
                onPressed: loading ? null : signup,
                child: loading
                    ? Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(
                          strokeWidth: 3,
                        ),
                      )
                    : Text(str.agreeAndCheckAccountStatus.toUpperCase()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(str.bigTechAntiCompetitionStatement),
              ),
            ],
          ),
        ),
      ),
      contentPadding: EdgeInsets.fromLTRB(24, 24, 24, 0),
    );
  }
}
