import 'dart:async';

import 'package:base32/base32.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/logging/logger.dart';
import 'package:keevault/model/entry.dart';

import 'package:clock/clock.dart';
import 'package:keevault/model/field.dart';
import 'package:otp/otp.dart';
import '../kee_clipboard.dart';
import '../otpauth.dart';
import '../generated/l10n.dart';
import 'dialog_utils.dart';
import 'entry.dart';
import 'entry_totp.dart';
import '../extension_methods.dart';

class EntryField extends StatefulWidget {
  const EntryField({
    Key? key,
    required this.fieldType,
    required this.entry,
    required this.field,
    required this.onDelete,
    required this.onChangeIcon,
  }) : super(key: key);

  final FieldType fieldType;
  final EditEntryViewModel entry;
  final FieldViewModel field;
  final VoidCallback onDelete;

  // This technically relates to an entry operation rather than field operation but the layout of the
  // app may lead some users to expect to find it in the menu for the Title field.
  final VoidCallback onChangeIcon;

  @override
  // Ignoring because I can't work out why this can be a problem
  // ignore: no_logic_in_create_state
  State<EntryField> createState() => fieldType == FieldType.otp
      ? _OtpEntryFieldState()
      : fieldType == FieldType.checkbox
          ? _SwitchEntryFieldState()
          : _EntryTextFieldState();
}

class _SwitchEntryFieldState extends _EntryFieldState {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    if (widget.field.browserModel!.value == 'KEEFOX_CHECKED_FLAG_TRUE') {
      _checked = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    l.d('building ${widget.key} ($_checked)');
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: ListTile(
              title: Text(widget.field.name?.nullIfBlank() ?? '[no name]'),
              leading: Switch(
                key: _formFieldKey,
                value: _checked,
                onChanged: (bool? value) {
                  final cubit = BlocProvider.of<EntryCubit>(context);
                  cubit.updateField(null, widget.field.browserModel!.displayName,
                      value: value! ? PlainValue('KEEFOX_CHECKED_FLAG_TRUE') : PlainValue('KEEFOX_CHECKED_FLAG_FALSE'),
                      browserModel: widget.field.browserModel!
                          .copyWith(value: value ? 'KEEFOX_CHECKED_FLAG_TRUE' : 'KEEFOX_CHECKED_FLAG_FALSE'));
                  _checked = value;
                },
              ),
            ),
          ),
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: PopupMenuButton<EntryAction>(
              icon: const Icon(Icons.more_vert),
              offset: const Offset(0, 32),
              onSelected: (EntryAction entryAction) async => await _handleMenuEntrySelected(context, entryAction),
              itemBuilder: _buildMenuEntries,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuEntrySelected(BuildContext context, EntryAction entryAction) async {
    final str = S.of(context);
    switch (entryAction) {
      case EntryAction.rename:
        final cubit = BlocProvider.of<EntryCubit>(context);
        final newName = await SimplePromptDialog(
          title: str.renamingField,
          labelText: str.renameFieldEnterNewName,
          initialValue: widget.field.name,
        ).show(context);
        if (newName != null) {
          cubit.renameField(widget.field.key, widget.field.browserModel?.displayName, newName);
        }
        break;
      case EntryAction.delete:
        widget.onDelete();
        break;
      default:
        break;
    }
  }

  List<PopupMenuEntry<EntryAction>> _buildMenuEntries(BuildContext context) {
    final str = S.of(context);
    final mutableMenuItems = <PopupMenuEntry<EntryAction>>[];

    if (widget.field.keyChangeable) {
      mutableMenuItems.addAll([
        PopupMenuItem(
          value: EntryAction.rename,
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: Text(str.tagRename),
          ),
        ),
        PopupMenuItem(
          value: EntryAction.delete,
          child: ListTile(
            leading: const Icon(Icons.delete),
            title: Text(str.detDelEntry),
          ),
        ),
      ]);
    }
    if (mutableMenuItems.length > 1) {
      mutableMenuItems.insert(0, const PopupMenuDivider());
    }
    return mutableMenuItems.toList();
  }

  @override
  void dispose() {
    l.d('EntryFieldState.dispose() - ${widget.key} (${widget.field.key})');
    super.dispose();
  }
}

abstract class _EntryFieldState extends State<EntryField> {
  final GlobalKey _formFieldKey = GlobalKey();
}

class _EntryTextFieldState extends _EntryFieldState implements FieldDelegate {
  late TextEditingController _controller;
  bool _isValueObscured = false;
  final FocusNode _focusNode = FocusNode();

  bool get _isProtected => widget.field.value is ProtectedValue;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_focusNodeChanged);
    _initController();
  }

  void _initController() {
    if ((widget.field.value is ProtectedValue || widget.field.protect == true) &&
        widget.field.value.getText().isNotEmpty) {
      _isValueObscured = true;
    } else {
      _isValueObscured = false;
    }
    _controller = TextEditingController(text: widget.field.textValue);
  }

  @override
  Widget build(BuildContext context) {
    l.d('building ${widget.key} ($_isValueObscured)');
    final str = S.of(context);
    return Dismissible(
      key: ValueKey(widget.field.key),
      background: Container(
        alignment: Alignment.centerLeft,
        color: Theme.of(context).primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.content_copy),
                const SizedBox(height: 4),
                Text(str.alertCopy),
              ],
            ),
            Spacer(),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.content_copy),
                const SizedBox(height: 4),
                Text(str.alertCopy),
              ],
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        await copyValue();
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _buildEntryFieldEditor(),
            ),
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: PopupMenuButton<EntryAction>(
                icon: const Icon(Icons.more_vert),
                offset: const Offset(0, 32),
                onSelected: (EntryAction entryAction) async => await _handleMenuEntrySelected(context, entryAction),
                itemBuilder: _buildMenuEntries,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _focusNodeChanged() {
    if (!_isProtected) {
      return;
    }
  }

  Future<void> _handleMenuEntrySelected(BuildContext context, EntryAction entryAction) async {
    final str = S.of(context);
    switch (entryAction) {
      case EntryAction.copy:
        await copyValue();
        break;
      case EntryAction.copyRawData:
        // only used by [_OtpEntryFieldState]
        throw UnsupportedError('Field does not support this action.');
      case EntryAction.rename:
        // Think this is a use_build_context_synchronously false positive at least
        // as of Dart 3.1 but a quick sanity check here does minimal harm
        if (context.mounted) {
          final cubit = BlocProvider.of<EntryCubit>(context);
          final newName = await SimplePromptDialog(
            title: str.renamingField,
            labelText: str.renameFieldEnterNewName,
            initialValue: widget.field.name,
          ).show(context);
          if (newName != null) {
            cubit.renameField(widget.field.key, widget.field.browserModel?.displayName, newName);
          }
        }
        break;
      case EntryAction.protect:
        // Think this is a use_build_context_synchronously false positive at least
        // as of Dart 3.1 but a quick sanity check here does minimal harm
        if (context.mounted) {
          if (_isProtected) {
            final cubit = BlocProvider.of<EntryCubit>(context);
            if (widget.field.fieldStorage == FieldStorage.JSON) {
              cubit.updateField(
                null,
                widget.field.browserModel!.displayName,
                value: PlainValue(widget.field.textValue),
                browserModel:
                    widget.field.browserModel!.copyWith(type: FormFieldType.TEXT, value: widget.field.textValue),
                protect: false,
              );
            } else {
              cubit.updateField(
                widget.field.key,
                null,
                value: PlainValue(widget.field.textValue),
                protect: false,
              );
            }
          } else {
            final cubit = BlocProvider.of<EntryCubit>(context);
            if (widget.field.fieldStorage == FieldStorage.JSON) {
              cubit.updateField(
                null,
                widget.field.browserModel!.displayName,
                value: ProtectedValue.fromString(widget.field.textValue),
                browserModel:
                    widget.field.browserModel!.copyWith(type: FormFieldType.PASSWORD, value: widget.field.textValue),
                protect: true,
              );
            } else {
              cubit.updateField(
                widget.field.key,
                null,
                value: ProtectedValue.fromString(widget.field.textValue),
                protect: true,
              );
            }
          }
          setState(() {
            if (_isProtected) {
              _isValueObscured = false;
            } else if (widget.field.textValue.isNotEmpty) {
              _isValueObscured = true;
            }
          });
        }
        break;
      case EntryAction.delete:
        widget.onDelete();
        break;
      case EntryAction.changeIcon:
        widget.onChangeIcon();
        break;
      case EntryAction.openInBrowser:
        if (widget.field.textValue.isNotEmpty) {
          await DialogUtils.openUrl(widget.field.textValue);
        }
        break;
    }
  }

  List<PopupMenuEntry<EntryAction>> _buildMenuEntries(BuildContext context) {
    final str = S.of(context);
    final immutableMenuItems = <PopupMenuEntry<EntryAction>>[
      PopupMenuItem(
        value: EntryAction.copy,
        child: ListTile(
          leading: const Icon(Icons.content_copy),
          title: Text(str.alertCopy),
        ),
      ),
    ];
    final mutableMenuItems = <PopupMenuEntry<EntryAction>>[];

    if (widget.field.name == KdbxKeyCommon.KEY_TITLE) {
      mutableMenuItems.add(PopupMenuItem(
        value: EntryAction.changeIcon,
        child: ListTile(
          leading: const Icon(Icons.check_box_outline_blank_rounded),
          title: Text(str.detSetIcon),
        ),
      ));
    }

    if (widget.field.name == KdbxKeyCommon.KEY_URL && widget.field.textValue.isNotEmpty) {
      mutableMenuItems.add(PopupMenuItem(
        value: EntryAction.openInBrowser,
        child: ListTile(
          leading: const Icon(Icons.open_in_new),
          title: Text(str.openInBrowser),
        ),
      ));
    }

    if (widget.field.protectionChangeable) {
      mutableMenuItems.add(PopupMenuItem(
        value: EntryAction.protect,
        child: ListTile(
          leading: Icon(_isProtected ? Icons.no_encryption : Icons.enhanced_encryption),
          title: Text(_isProtected ? str.unprotectField : str.protectField),
        ),
      ));
    }
    if (widget.field.keyChangeable) {
      mutableMenuItems.add(PopupMenuItem(
        value: EntryAction.rename,
        child: ListTile(
          leading: const Icon(Icons.edit),
          title: Text(str.tagRename),
        ),
      ));
    }
    if (widget.field.keyChangeable || widget.field.isTotp) {
      mutableMenuItems.add(PopupMenuItem(
        value: EntryAction.delete,
        child: ListTile(
          leading: const Icon(Icons.delete),
          title: Text(str.detDelEntry),
        ),
      ));
    }

    if (mutableMenuItems.length > 1) {
      mutableMenuItems.insert(0, const PopupMenuDivider());
    }
    return immutableMenuItems.followedBy(mutableMenuItems).toList();
  }

  @override
  Future<void> openUrl() async {
    throw Exception('not implemented');
  }

  Future<bool> copyValue() async {
    final sm = ScaffoldMessenger.of(context);
    final str = S.of(context);
    final isSensitive = widget.field.value is ProtectedValue || widget.field.protect == true;
    final userNotified = await KeeClipboard.set(widget.field.textValue, isSensitive);
    if (!userNotified) {
      sm.showSnackBar(SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(str.detFieldCopied),
          ],
        ),
        duration: Duration(seconds: 3),
      ));
    }
    return true;
  }

  Widget _buildEntryFieldEditor() => _isValueObscured && widget.field.textValue.isEmpty == false
      ? _buildObscuredEntryFieldEditor()
      : _buildStringEntryFieldEditor();

  Widget _buildObscuredEntryFieldEditor() {
    return ObscuredEntryFieldEditor(
      onPressed: () {
        setState(() {
          _controller.text = widget.field.textValue;
          _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
          _isValueObscured = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _focusNode.requestFocus();
            l.d('requesting focus.');
          });
        });
      },
      field: widget.field,
    );
  }

  Widget _buildStringEntryFieldEditor() {
    return StringEntryFieldEditor(
      onChange: (value) {
        final StringValue? newValue = value == null
            ? null
            : _isProtected
                ? ProtectedValue.fromString(value)
                : PlainValue(value);
        final cubit = BlocProvider.of<EntryCubit>(context);
        if (widget.field.fieldStorage == FieldStorage.JSON) {
          if (widget.field.browserModel!.value == value) {
            // Flutter can call onChange when no changes have occurred!
            return;
          }
          cubit.updateField(
            null,
            widget.field.browserModel!.displayName,
            value: newValue,
            browserModel: widget.field.browserModel!.copyWith(value: value),
          );
        } else {
          if (widget.field.value.getText() == value) {
            // Flutter can call onChange when no changes have occurred!
            return;
          }
          cubit.updateField(
            widget.field.key,
            null,
            value: newValue,
          );
        }
      },
      fieldKey: widget.field.key,
      controller: _controller,
      formFieldKey: _formFieldKey,
      focusNode: _focusNode,
      delegate: this,
      field: widget.field,
    );
  }

  @override
  void dispose() {
    l.d('EntryFieldState.dispose() - ${widget.key} (${widget.field.key})');
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _OtpEntryFieldState extends _EntryTextFieldState {
  Timer? _timer;

  String _currentOtp = '';

  String? _errorMessage;

  // elapsed seconds since the last period change.
  int _elapsed = 0;

  // period in seconds how often the otp changes.
  int _period = 30;

  OtpAuth _getOtpAuth() {
    final value = widget.field.textValue;
    if (value.isEmpty) {
      return throw FormatException('OTP Field contains no data.', value);
    }
    if (value.startsWith('otpauth:')) {
      return OtpAuth.fromUri(Uri.parse(value));
    }

    throw FormatException('Unknown format for OTP', value);
  }

  void _updateOtp() {
    try {
      final otpAuth = _getOtpAuth();
      final secretBase32 = base32.encode(otpAuth.secret);
      final now = clock.now().millisecondsSinceEpoch;
      final totpCode = OTP.generateTOTPCodeString(
        secretBase32,
        now,
        algorithm: otpAuth.algorithm,
        length: otpAuth.digits,
        interval: otpAuth.period,
        // do not pad OTP secret if it is not of correct length.
        isGoogle: true,
      );
      setState(() {
        _elapsed = (now ~/ 1000) % otpAuth.period;
        _period = otpAuth.period;
        _currentOtp = totpCode;
        _errorMessage = null;
      });
    } on FormatException catch (e, stackTrace) {
      l.e('Error while decoding otpauth url.', e, stackTrace);
      setState(() {
        _currentOtp = '';
        _errorMessage = 'Error generating token $e';
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timer == null) {
      _updateOtp();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateOtp();
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<bool> copyValue() async {
    l.d('Copying OTP value.');
    final sm = ScaffoldMessenger.of(context);
    final str = S.of(context);
    final userNotified = await KeeClipboard.set(_currentOtp, true);
    if (!userNotified) {
      sm.showSnackBar(SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(str.detFieldCopied),
          ],
        ),
        duration: Duration(seconds: 3),
      ));
    }
    return true;
  }

  @override
  Widget _buildEntryFieldEditor() => _errorMessage != null
      ? Text('$_errorMessage')
      : OtpFieldEntryEditor(
          period: _period,
          elapsed: _elapsed,
          otpCode: _currentOtp,
        );

  @override
  Future<void> _handleMenuEntrySelected(BuildContext context, EntryAction entryAction) async {
    if (entryAction == EntryAction.copyRawData) {
      l.d('Copying raw OTP data.');
      final sm = ScaffoldMessenger.of(context);
      final str = S.of(context);
      final userNotified = await KeeClipboard.set(widget.field.textValue, true);
      if (!userNotified) {
        sm.showSnackBar(SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(str.detFieldCopied),
            ],
          ),
          duration: Duration(seconds: 3),
        ));
      }
      return;
    }
    return super._handleMenuEntrySelected(context, entryAction);
  }

  @override
  List<PopupMenuEntry<EntryAction>> _buildMenuEntries(BuildContext context) {
    final str = S.of(context);
    return super
        ._buildMenuEntries(context)
        .where((item) =>
            item is PopupMenuItem &&
            const [
              EntryAction.delete,
              EntryAction.copy,
            ].contains((item as PopupMenuItem).value))
        .followedBy([
      PopupMenuItem(
        value: EntryAction.copyRawData,
        child: ListTile(
          leading: Icon(Icons.code),
          title: Text(str.copySecret),
        ),
      )
    ]).toList();
  }
}
