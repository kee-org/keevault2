import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kdbx/kdbx.dart';
import '../cubit/vault_cubit.dart';
import '../generated/l10n.dart';
import '../widgets/password_strength.dart';
import 'coloured_safe_area_widget.dart';

class ChangePasswordWidget extends StatefulWidget {
  const ChangePasswordWidget({Key? key}) : super(key: key);

  @override
  State<ChangePasswordWidget> createState() => _ChangePasswordWidgetState();
}

class _ChangePasswordWidgetState extends State<ChangePasswordWidget> {
  final _formKey = GlobalKey<FormState>();
  String? submittedValue;
  final TextEditingController _currentPassword = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  late bool saveError;
  late bool saving;

  @override
  void initState() {
    super.initState();
    saving = false;
    saveError = false;
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return ColouredSafeArea(
      child: Scaffold(
        key: widget.key,
        appBar: AppBar(title: Text(str.changePassword)),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SafeArea(
              top: false,
              left: false,
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        str.changePasswordDetail,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(str.enterOldPassword),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
                      child: TextFormField(
                        controller: _currentPassword,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: str.currentPassword,
                          errorText: null,
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? false) {
                            return str.this_field_required;
                          }
                          if (!checkCurrentPassword(value)) {
                            return str.currentPasswordNotCorrect;
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(str.registrationBlurb1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextFormField(
                        controller: _password,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: str.newPassword,
                          errorText: null,
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? false) {
                            return str.this_field_required;
                          }
                          return null;
                        },
                      ),
                    ),
                    ValueListenableBuilder(
                        valueListenable: _password,
                        builder: (context, TextEditingValue content, child) {
                          return PasswordStrengthWidget(
                            testValue: content.text,
                          );
                        }),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextFormField(
                        controller: _confirmPassword,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: str.newPasswordRepeat,
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
                      ),
                    ),
                    Visibility(
                      visible: saveError,
                      child: Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            'There was a problem saving your new password. Please try again in a moment and then check that your device storage has free space and is not faulty.',
                            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
                          )),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final navigator = Navigator.of(context);
                                final sm = ScaffoldMessenger.of(context);
                                setState(() {
                                  saveError = false;
                                });
                                if (_formKey.currentState!.validate()) {
                                  setState(() {
                                    saving = true;
                                  });
                                  _formKey.currentState!.save();
                                  try {
                                    await changePassword(submittedValue!);
                                    setState(() {
                                      saving = false;
                                    });
                                    sm.showSnackBar(SnackBar(
                                      content: Text(str.passwordChanged),
                                      duration: Duration(seconds: 4),
                                    ));
                                    navigator.pop();
                                  } on Exception {
                                    setState(() {
                                      saving = false;
                                      saveError = true;
                                    });
                                  }
                                }
                              },
                        child: saving
                            ? Container(
                                width: 24,
                                height: 24,
                                padding: const EdgeInsets.all(2.0),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
                              )
                            : Text(str.changePassword),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool checkCurrentPassword(String? value) {
    if (value == null) {
      return false;
    }
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    final currentHash = vaultCubit.currentVaultFile!.files.current.credentials.getHash();
    final newHash = Credentials(ProtectedValue.fromString(value)).getHash();
    if (ListEquality().equals(newHash, currentHash)) {
      return true;
    }
    return false;
  }

  Future<void> changePassword(String password) async {
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    await vaultCubit.changeFreeUserPassword(password);
  }
}
