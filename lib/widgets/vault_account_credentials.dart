import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../generated/l10n.dart';

typedef SubmitCallback = Future<void> Function(String string);

class VaultAccountCredentialsWidget extends StatefulWidget {
  const VaultAccountCredentialsWidget({
    Key? key,
    required this.onSubmit,
    required this.onLocalOnlyRequested,
  }) : super(key: key);

  final SubmitCallback onSubmit;
  final void Function() onLocalOnlyRequested;

  @override
  _VaultAccountCredentialsWidgetState createState() => _VaultAccountCredentialsWidgetState();
}

class _VaultAccountCredentialsWidgetState extends State<VaultAccountCredentialsWidget> {
  final _formKey = GlobalKey<FormState>();
  String? submittedValue;

  submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      await widget.onSubmit(submittedValue!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.headline6,
              children: <TextSpan>[
                TextSpan(
                  text: 'Sign in to your Kee Vault account or ',
                  style: theme.textTheme.headline6,
                ),
                TextSpan(
                  text: 'use the app for free',
                  style: theme.textTheme.headline6!.copyWith(color: theme.primaryColor),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      widget.onLocalOnlyRequested();
                    },
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: str.enter_your_email_address,
                    labelText: str.email,
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? false) {
                      return str.this_field_required;
                    }
                    return null;
                  },
                  onSaved: (String? value) {
                    submittedValue = value?.trim().toLowerCase();
                  },
                  onFieldSubmitted: (value) async {
                    if (_formKey.currentState!.validate()) {
                      await widget.onSubmit(value);
                    }
                  },
                  autofocus: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: ElevatedButton(
                  onPressed: submit,
                  child: Text(str.signin),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
