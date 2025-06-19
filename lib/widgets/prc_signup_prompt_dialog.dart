import 'package:flutter/material.dart';
import 'package:keevault/widgets/prc_privacy_dialog.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import '../config/environment_config.dart';
import '../vault_backend/mailer_service.dart';
import 'dialog_utils.dart';
import 'package:keevault/generated/l10n.dart';
import 'package:email_validator/email_validator.dart';
import 'package:keevault/logging/logger.dart';

class PRCSignupPromptDialog extends StatefulWidget with DialogMixin<bool> {
  const PRCSignupPromptDialog({super.key});

  @override
  State<PRCSignupPromptDialog> createState() => _PRCSignupPromptDialogState();

  @override
  String get name => '/dialog/prcSignupPrompt';
}

class _PRCSignupPromptDialogState extends State<PRCSignupPromptDialog>
    with WidgetsBindingObserver, TraceableClientMixin {
  @override
  String get actionName => widget.toStringShort();

  late TextEditingController _controller;
  AppLifecycleState? _previousState;
  late bool loading;
  late bool error;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    loading = false;
    error = false;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    l.d('lifecycle state changed to $state (was: $_previousState)');
    _previousState = state;
  }

  Future<void> signup() async {
    final str = S.of(context);
    final navigator = Navigator.of(context);
    final sm = ScaffoldMessenger.of(context);
    if (formKey.currentState?.validate() ?? false) {
      l.d('signing up supplied email address');
      setState(() {
        loading = true;
        error = false;
      });
      final mailerService = MailerService(EnvironmentConfig.stage.toStage(), null);
      final result = await mailerService.signup(_controller.text.toLowerCase());
      if (result) {
        l.d('signup successful');
        navigator.pop(true);
        sm.showSnackBar(SnackBar(content: Text(str.prcRegistrationSuccess)));
        MatomoTracker.instance.trackEvent(
          eventInfo: EventInfo(category: 'main', action: 'prcSignup', name: 'free'),
        );
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
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
                  validator: (val) => !EmailValidator.validate(val ?? '') ? str.emailValidationFail : null,
                  style: theme.textTheme.titleMedium!.copyWith(color: theme.colorScheme.tertiary),
                ),
              ),
              TextButton(
                onPressed: () async => await PrcPrivacyDialog().show(context),
                child: Text(
                  str.privacyStatement,
                  style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.tertiary),
                ),
              ),
              Visibility(
                visible: error,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(str.prcRegistrationError),
                ),
              ),
            ],
          ),
        ),
      ),
      contentPadding: EdgeInsets.fromLTRB(24, 24, 24, 0),
      actions: <Widget>[
        TextButton(
          onPressed: loading ? null : signup,
          child: loading
              ? Container(
                  width: 24,
                  height: 24,
                  padding: const EdgeInsets.all(2.0),
                  child: const CircularProgressIndicator(
                    //color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : Text(str.prcRegistrationSignUpButton.toUpperCase()),
        ),
      ],
    );
  }
}
