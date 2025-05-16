import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../generated/l10n.dart';
import 'free_user_dialog.dart';
import 'password_strength.dart';

typedef SubmitCallback = Future<void> Function(String string);

class VaultLocalOnlyCreateWidget extends StatefulWidget {
  const VaultLocalOnlyCreateWidget({super.key, required this.onSubmit, required this.showError});

  final bool showError;
  final SubmitCallback onSubmit;

  @override
  State<VaultLocalOnlyCreateWidget> createState() => _VaultLocalOnlyCreateWidgetState();
}

class _VaultLocalOnlyCreateWidgetState extends State<VaultLocalOnlyCreateWidget> {
  final _formKey = GlobalKey<FormState>();
  String? submittedValue;
  bool _userAgreed = false;
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  bool password1Obscured = true;
  bool password2Obscured = true;

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    final mainColor = theme.brightness == Brightness.dark ? theme.colorScheme.secondary : theme.colorScheme.primary;
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(str.chooseAPassword, style: theme.textTheme.titleLarge),
            ),
            Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Text(str.localOnlyIntro)),
            Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Text(str.registrationBlurb1)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextFormField(
                controller: _password,
                obscureText: password1Obscured,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: str.newPassword,
                  errorText: null,
                  suffixIcon: IconButton(
                    icon: Icon(password1Obscured ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        password1Obscured = !password1Obscured;
                      });
                    },
                  ),
                  suffixIconColor: theme.brightness == Brightness.light ? theme.primaryColor : Colors.white,
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
                keyboardType: TextInputType.visiblePassword,
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _password,
              builder: (context, TextEditingValue content, child) {
                return PasswordStrengthWidget(testValue: content.text);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextFormField(
                controller: _confirmPassword,
                obscureText: password2Obscured,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: str.newPasswordRepeat,
                  errorText: widget.showError ? str.setFilePassNotMatch : null,
                  suffixIcon: IconButton(
                    icon: Icon(password2Obscured ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        password2Obscured = !password2Obscured;
                      });
                    },
                  ),
                  suffixIconColor: theme.brightness == Brightness.light ? theme.primaryColor : Colors.white,
                ),
                validator: (value) {
                  if (value?.isEmpty ?? false) {
                    return str.this_field_required;
                  }
                  if (value != _password.text) {
                    return str.setFilePassNotMatch;
                  }
                  return null;
                },
                onSaved: (String? value) {
                  submittedValue = value;
                },
                keyboardType: TextInputType.visiblePassword,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: <TextSpan>[
                    TextSpan(text: str.localOnlyAgree1),
                    TextSpan(
                      text: str.localOnlyAgree2,
                      style: theme.textTheme.bodyMedium!.copyWith(color: mainColor, fontWeight: FontWeight.bold),
                      recognizer:
                          TapGestureRecognizer()
                            ..onTap = () async {
                              await FreeUserTermsDialog().show(context);
                            },
                    ),
                    TextSpan(text: str.localOnlyAgree3),
                  ],
                ),
              ),
            ),
            CheckboxListTile(
              value: _userAgreed,
              title: Text(str.localOnlyAgree4),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              onChanged: (bool? value) {
                setState(() {
                  _userAgreed = value!;
                });
              },
            ),
            ElevatedButton(
              onPressed:
                  _userAgreed
                      ? () async {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          await widget.onSubmit(submittedValue!);
                        }
                      }
                      : null,
              child: Text(str.createVault),
            ),
          ],
        ),
      ),
    );
  }
}
