import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jiffy/jiffy.dart';
import 'package:kdbx/kdbx.dart' hide FieldType;
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/extension_methods.dart';
import 'package:keevault/model/entry.dart';
import 'package:keevault/model/field.dart';
import 'package:keevault/widgets/binaries.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import '../kee_clipboard.dart';
import '../generated/l10n.dart';
import 'coloured_safe_area_widget.dart';
import 'dialog_utils.dart';
import 'entry.dart';

class EntryHistoryWidget extends StatelessWidget {
  final Function(int index) revertTo;
  final Function(int index) deleteAt;

  const EntryHistoryWidget({super.key, required this.revertTo, required this.deleteAt});

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return TraceableWidget(
      actionName: 'EntryHistory',
      child: BlocBuilder<EntryCubit, EntryState>(
        builder: (context, state) {
          if (state is! EntryLoaded) return Container();
          final EditEntryViewModel entry = state.entry;
          return ColouredSafeArea(
            child: Scaffold(
              key: key,
              appBar: AppBar(title: Text(str.entryHistory)),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: SafeArea(
                    top: false,
                    left: false,
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.0),
                          child: Text(str.entryHistoryExplainer),
                        ),
                        ...entry.history
                            .asMap()
                            .entries
                            .map((mapEntry) {
                              final historyIndex = mapEntry.key;
                              final historyEntry = mapEntry.value;
                              return EntryHistoryItem(
                                revert: () async {
                                  final navigator = Navigator.of(context);
                                  if (entry.isDirty) {
                                    final proceed = await DialogUtils.showConfirmDialog(
                                      context: context,
                                      params: ConfirmDialogParams(
                                        content: str.revertUnsavedWarning,
                                        negativeButtonText: str.alertNo,
                                        positiveButtonText: str.discardChanges,
                                      ),
                                    );
                                    if (!proceed) {
                                      return;
                                    }
                                  }
                                  if (!context.mounted) {
                                    return;
                                  }
                                  final proceed = await DialogUtils.showConfirmDialog(
                                    context: context,
                                    params: ConfirmDialogParams(
                                      content: str.detHistoryRevertAlert,
                                      negativeButtonText: str.alertNo,
                                      positiveButtonText: str.detHistoryRevert,
                                    ),
                                  );
                                  if (!proceed) {
                                    return;
                                  }
                                  navigator.pop(true);
                                  revertTo(historyIndex);
                                },
                                delete: () => {},
                                entry: historyEntry,
                              );
                            })
                            .toList()
                            .reversed,
                      ],
                    ),
                  ),
                ),
              ),
              extendBody: true,
            ),
          );
        },
      ),
    );
  }
}

class EntryHistoryItem extends StatelessWidget {
  final Function() revert;
  final Function() delete;
  final EntryViewModel entry;
  const EntryHistoryItem({super.key, required this.revert, required this.entry, required this.delete});

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
      child: Card(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(width: 16),
                  entry.getIcon(48, Theme.of(context).brightness == Brightness.dark),
                  const SizedBox(width: 4),
                  Expanded(
                    child: entry.fields
                        .take(1)
                        .map((f) => EntryHistoryField(fieldType: FieldType.string, field: f))
                        .first,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...entry.fields
                  .skip(1)
                  .map(
                    (f) => EntryHistoryField(
                      fieldType: f.isTotp
                          ? FieldType.otp
                          : f.isCheckbox
                          ? FieldType.checkbox
                          : FieldType.string,
                      field: f,
                    ),
                  )
                  .expand((el) => [el, const SizedBox(height: 8)]),
              ...entry.binaryMapEntries.isEmpty
                  ? []
                  : entry.binaryMapEntries.map((e) {
                      return BinaryCardWidget(
                        key: ValueKey('${e.key}-${e.value.valueHashCode}'),
                        entry: entry,
                        attachment: e,
                        readOnly: true,
                      );
                    }),
              Divider(indent: 16, endIndent: 16),
              Row(
                children: [
                  Padding(padding: const EdgeInsets.all(16.0), child: Text(str.labels)),
                  Expanded(
                    child: Wrap(
                      children: entry.tags
                          .map(
                            (tag) => Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: InputChip(
                                label: Text(tag.name),
                                padding: EdgeInsets.all(0.0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4.0))),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                labelPadding: EdgeInsets.symmetric(horizontal: 8.0),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Padding(padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0), child: Text(str.color)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0.0, 16.0, 0.0, 16.0),
                    child: Text(enumToString(entry.color) ?? ''),
                  ),
                ],
              ),
              IntegrationSettingsHistoryWidget(entry: entry),
              Row(
                children: [
                  Padding(padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0), child: Text(str.detCreated)),
                  Tooltip(
                    message:
                        '${Jiffy.parseFromDateTime(entry.createdTime.toLocal()).yMMMMEEEEd} ${Jiffy.parseFromDateTime(entry.createdTime.toLocal()).jms}',
                    child: Text(Jiffy.parseFromDateTime(entry.createdTime).fromNow()),
                  ),
                ],
              ),
              Row(
                children: [
                  Padding(padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0), child: Text(str.detUpdated)),
                  Tooltip(
                    message:
                        '${Jiffy.parseFromDateTime(entry.modifiedTime.toLocal()).yMMMMEEEEd} ${Jiffy.parseFromDateTime(entry.modifiedTime.toLocal()).jms}',
                    child: Text(Jiffy.parseFromDateTime(entry.modifiedTime).fromNow()),
                  ),
                ],
              ),
              OutlinedButton(onPressed: revert, child: Text(str.resetEntryToThis)),
            ],
          ),
        ),
      ),
    );
  }
}

class EntryHistoryField extends StatelessWidget {
  const EntryHistoryField({super.key, required this.fieldType, required this.field});

  final FieldType fieldType;
  final FieldViewModel field;

  @override
  Widget build(BuildContext context) {
    return fieldType == FieldType.otp
        ? EntryHistoryFieldOtp(field: field)
        : fieldType == FieldType.checkbox
        ? EntryHistoryFieldBoolean(field: field)
        : EntryHistoryFieldText(field: field);
  }
}

class EntryHistoryFieldOtp extends StatelessWidget {
  const EntryHistoryFieldOtp({super.key, required this.field});

  final FieldViewModel field;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Text('${field.name?.nullIfBlank() ?? '[no name]'}: [OTP]'),
      ),
    );
  }
}

class EntryHistoryFieldBoolean extends StatelessWidget {
  const EntryHistoryFieldBoolean({super.key, required this.field});

  final FieldViewModel field;

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final checked = field.browserModel!.value == 'KEEFOX_CHECKED_FLAG_TRUE' ? str.enabled : str.disabled;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Text('${field.name?.nullIfBlank() ?? '[no name]'}: $checked'),
    );
  }
}

class EntryHistoryFieldText extends StatefulWidget {
  const EntryHistoryFieldText({super.key, required this.field});
  final FieldViewModel field;

  @override
  State<EntryHistoryFieldText> createState() => _EntryHistoryFieldTextState();
}

class _EntryHistoryFieldTextState extends State<EntryHistoryFieldText> {
  bool _isValueObscured = false;

  bool get _isProtected => widget.field.value is ProtectedValue;

  @override
  void initState() {
    super.initState();
    _initView();
  }

  void _initView() {
    if ((widget.field.value is ProtectedValue || widget.field.protect == true) &&
        widget.field.value.getText().isNotEmpty) {
      _isValueObscured = true;
    } else {
      _isValueObscured = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return Dismissible(
      key: ValueKey(widget.field.key),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[const Icon(Icons.content_copy), const SizedBox(height: 4), Text(str.alertCopy)],
            ),
            Spacer(),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[const Icon(Icons.content_copy), const SizedBox(height: 4), Text(str.alertCopy)],
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
            Expanded(child: _buildEntryFieldViewer()),
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: PopupMenuButton<EntryAction>(
                icon: const Icon(Icons.more_vert),
                offset: const Offset(0, 32),
                onSelected: _handleMenuEntrySelected,
                itemBuilder: _buildMenuEntries,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<EntryAction>> _buildMenuEntries(BuildContext context) {
    final str = S.of(context);
    final immutableMenuItems = <PopupMenuEntry<EntryAction>>[
      PopupMenuItem(
        value: EntryAction.copy,
        child: ListTile(leading: const Icon(Icons.content_copy), title: Text(str.alertCopy)),
      ),
    ];
    final mutableMenuItems = <PopupMenuEntry<EntryAction>>[];

    if (_isProtected) {
      mutableMenuItems.add(
        PopupMenuItem(
          value: EntryAction.protect,
          child: ListTile(
            leading: Icon(_isValueObscured ? Icons.no_encryption : Icons.enhanced_encryption),
            title: Text(_isValueObscured ? str.show : str.hide),
          ),
        ),
      );
    }
    return immutableMenuItems.followedBy(mutableMenuItems).toList();
  }

  Future<void> _handleMenuEntrySelected(EntryAction entryAction) async {
    switch (entryAction) {
      case EntryAction.copy:
        await copyValue();
        break;
      case EntryAction.protect:
        setState(() {
          _isValueObscured = !_isValueObscured;
        });
        break;
      default:
        break;
    }
  }

  Future<bool> copyValue() async {
    final sm = ScaffoldMessenger.of(context);
    final str = S.of(context);
    final isSensitive = widget.field.value is ProtectedValue || widget.field.protect == true;
    final userNotified = await KeeClipboard.set(widget.field.textValue, isSensitive);
    if (!userNotified) {
      sm.showSnackBar(
        SnackBar(
          content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(str.detFieldCopied)]),
          duration: Duration(seconds: 3),
        ),
      );
    }
    return true;
  }

  Widget _buildEntryFieldViewer() => _isValueObscured && widget.field.textValue.isEmpty == false
      ? _buildObscuredEntryFieldViewer()
      : _buildStringEntryFieldViewer();

  Widget _buildObscuredEntryFieldViewer() {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Text('${widget.field.name?.nullIfBlank() ?? '[no name]'}: Protected field'),
    );
  }

  Widget _buildStringEntryFieldViewer() {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Text('${widget.field.name?.nullIfBlank() ?? '[no name]'}: ${widget.field.textValue}'),
    );
  }
}

class IntegrationSettingsHistoryWidget extends StatefulWidget {
  final EntryViewModel entry;
  const IntegrationSettingsHistoryWidget({super.key, required this.entry});

  @override
  State<IntegrationSettingsHistoryWidget> createState() => _IntegrationSettingsHistoryWidgetState();
}

class _IntegrationSettingsHistoryWidgetState extends State<IntegrationSettingsHistoryWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ExpansionPanelList(
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        children: [
          ExpansionPanel(
            canTapOnHeader: true,
            isExpanded: _isExpanded,
            headerBuilder: (context, isExpanded) => ListTile(title: Text(str.integrationSettings)),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Column(
                children: [
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ListTile(
                          title: Text(str.showEntryInBrowsersAndApps),
                          leading: Switch(
                            value: !widget.entry.browserSettings.matcherConfigs.any(
                              (mc) => mc.matcherType == EntryMatcherType.Hide,
                            ),
                            onChanged: null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(indent: 16, endIndent: 16),
                  Column(
                    children: widget.entry.browserSettings.includeUrls
                        .whereType<String>()
                        .cast<String>()
                        .map((s) => Text(s.toLowerCase()))
                        .toList(growable: false),
                  ),
                  Divider(indent: 16, endIndent: 16),
                  Row(
                    children: <Widget>[
                      Expanded(child: Text(str.minURLMatchAccuracy)),
                      Text(
                        (widget.entry.browserSettings.matcherConfigs
                                    .firstWhereOrNull((mc) => mc.matcherType == EntryMatcherType.Url)
                                    ?.urlMatchMethod ??
                                MatchAccuracy.Domain)
                            .name,
                      ),
                    ],
                  ),
                  Divider(indent: 16, endIndent: 16),
                  Column(
                    children: widget.entry.androidPackageNames
                        .map((s) => Text(s.toLowerCase()))
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
