import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:keevault/credentials/quick_unlocker.dart';
import '../config/platform.dart';
import '../generated/l10n.dart';
import '../logging/logger.dart';

typedef SubmitCallback = Future<void> Function(String string);
typedef BiometricCallback = Future<bool> Function();

class VaultPasswordCredentialsWidget extends StatefulWidget {
  const VaultPasswordCredentialsWidget({
    super.key,
    required this.reason,
    required this.onSubmit,
    this.forceBiometric,
    required this.showError,
    this.quStatus = QUStatus.unknown,
  });

  final String reason;
  final bool showError;
  final SubmitCallback onSubmit;
  final BiometricCallback? forceBiometric;
  final QUStatus quStatus;

  @override
  State<VaultPasswordCredentialsWidget> createState() => _VaultPasswordCredentialsWidgetState();
}

class _VaultPasswordCredentialsWidgetState extends State<VaultPasswordCredentialsWidget> {
  final _formKey = GlobalKey<FormState>();
  String? submittedValue;
  bool _showBiometricSigninButton = false;
  bool password1Obscured = true;

  @override
  void initState() {
    super.initState();
    _detectBiometrics();
  }

  _detectBiometrics() async {
    final hide =
        widget.forceBiometric == null ||
        widget.quStatus == QUStatus.mapAvailable ||
        widget.quStatus == QUStatus.unavailable ||
        !(Settings.getValue<bool>('biometrics-enabled') ?? true) ||
        !(await QuickUnlocker().supportsBiometricKeyStore()) ||
        widget.quStatus == QUStatus.mapAvailable ||
        widget.quStatus == QUStatus.unavailable;
    setState(() {
      _showBiometricSigninButton = !hide;
    });
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(widget.reason, style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    obscureText: password1Obscured,
                    autofillHints: KeeVaultPlatform.isIOS ? [AutofillHints.oneTimeCode] : null,
                    enableSuggestions: false,
                    autocorrect: false,
                    spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: str.enter_your_account_password,
                      labelText: str.password,
                      errorText: widget.showError
                          ? (widget.quStatus == QUStatus.mapAvailable ? str.biometricsMaybeExpired : str.tryAgain)
                          : null,
                      suffixIcon: IconButton(
                        icon: Icon(password1Obscured ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            password1Obscured = !password1Obscured;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? false) {
                        return str.this_field_required;
                      }
                      return null;
                    },
                    onSaved: (String? value) {
                      submittedValue = value;
                    },
                    onFieldSubmitted: (value) async {
                      if (_formKey.currentState!.validate()) {
                        await widget.onSubmit(value);
                      }
                    },
                    autofocus: true,
                    keyboardType: TextInputType.visiblePassword,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: FilledButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        await widget.onSubmit(submittedValue!);
                      }
                    },
                    child: Text(str.unlock),
                  ),
                ),
              ],
            ),
          ),
          widget.showError && widget.quStatus == QUStatus.mapAvailable
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(str.biometricsErrorExplanation(KeeVaultPlatform.isIOS ? 'Passcode' : 'PIN')),
                )
              : SizedBox.shrink(),
          _showBiometricSigninButton
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (!await widget.forceBiometric!()) {
                        l.w('Failed to force biometric signin');
                      }
                    },
                    label: Text(str.unlock_with_biometrics),
                    icon: Icon(Icons.fingerprint),
                  ),
                )
              : SizedBox.shrink(),
        ],
      ),
    );
  }
}
