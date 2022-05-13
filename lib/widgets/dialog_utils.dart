import 'dart:async';
import 'package:flutter/material.dart';
import 'package:keevault/logging/logger.dart';
import 'package:logger_flutter/logger_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../extension_methods.dart';
import 'package:keevault/generated/l10n.dart';

class DialogUtils {
  static Future<dynamic> showSimpleAlertDialog(
    BuildContext context,
    String? title,
    String content, {
    List<Widget>? moreActions,
    String routeName = '/dialog/alert/',
    required String routeAppend,
  }) {
    final materialLoc = MaterialLocalizations.of(context);
    return showDialog<dynamic>(
        context: context,
        routeSettings: RouteSettings(name: routeName + routeAppend),
        builder: (context) {
          return AlertDialog(
            scrollable: true,
            title: title == null ? null : Text(title),
            content: Text(content),
            actions: <Widget>[
              ...?moreActions,
              TextButton(
                child: Text(materialLoc.okButtonLabel),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  static Future<dynamic> showErrorDialog(
    BuildContext context,
    String? title,
    String content, {
    String? routeAppend,
  }) {
    final materialLoc = MaterialLocalizations.of(context);
    return showDialog<dynamic>(
        context: context,
        routeSettings: RouteSettings(name: '/dialog/alert/error${routeAppend?.prepend('/') ?? ''}'),
        builder: (context) {
          return AlertDialog(
            scrollable: true,
            title: title == null ? null : Text(title),
            content: SingleChildScrollView(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: LogConsoleOnShake(
                    dark: true,
                    child: Center(
                      child: Text(content),
                    ),
                  ),
                ),
              ],
            )),
            actions: <Widget>[
              TextButton(
                child: Text(S.of(context).openLogConsole),
                onPressed: () {
                  LogConsole.open(context);
                },
              ),
              TextButton(
                child: Text(materialLoc.okButtonLabel),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  static Future<bool> openUrl(String url) async {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  static Future<bool> showConfirmDialog({
    required BuildContext context,
    required ConfirmDialogParams params,
  }) async {
    return (await showDialog<bool>(
          context: context,
          routeSettings: const RouteSettings(name: '/dialog/confirm'),
          builder: (context) => ConfirmDialog(params: params),
        )) ==
        true;
  }
}

class ConfirmDialogParams {
  ConfirmDialogParams({
    this.title,
    required this.content,
    this.positiveButtonText = 'OK',
    this.negativeButtonText = 'CANCEL',
  });

  final String? title;
  final String content;
  final String positiveButtonText;
  final String negativeButtonText;
}

class ConfirmDialog extends StatelessWidget with DialogMixin<bool> {
  const ConfirmDialog({Key? key, required this.params}) : super(key: key);
  final ConfirmDialogParams params;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: params.title != null ? Text(params.title!) : null,
      content: Text(params.content),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(params.negativeButtonText),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(params.positiveButtonText),
        ),
      ],
    );
  }

  @override
  String get name => '/dialog/confirm';
}

mixin DialogMixin<T> on Widget {
  String get name;

  Future<T?> show(BuildContext context) => showDialog<T>(
        context: context,
        routeSettings: RouteSettings(name: name),
        builder: (context) => this,
      );
}

class SimplePromptDialog extends StatefulWidget with DialogMixin<String> {
  const SimplePromptDialog({
    Key? key,
    this.title,
    this.labelText,
    this.initialValue = '',
    this.helperText,
    this.bodyText,
    this.icon,
  }) : super(key: key);
  final String? title;
  final String? labelText;
  final String? helperText;
  final String? initialValue;
  final String? bodyText;
  final Widget? icon;

  @override
  _SimplePromptDialogState createState() => _SimplePromptDialogState();

  @override
  String get name => '/dialog/prompt/simple';
}

class _SimplePromptDialogState extends State<SimplePromptDialog> with WidgetsBindingObserver {
  late TextEditingController _controller;
  AppLifecycleState? _previousState;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final str = S.of(context);
    return AlertDialog(
      scrollable: true,
      title: widget.title == null ? null : Text(widget.title!),
      content: Container(
        constraints: const BoxConstraints(minWidth: 400.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Visibility(
              visible: widget.bodyText?.isNotEmpty ?? false,
              child: Flexible(
                child: Text(
                  widget.bodyText ?? '',
                  style: theme.textTheme.bodyText2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: widget.icon,
                  labelText: widget.labelText,
                  helperText: widget.helperText ?? '',
                  helperMaxLines: 1,
                ),
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                maxLines: 1,
                onEditingComplete: () {
                  Navigator.of(context).pop(_controller.text);
                },
              ),
            ),
          ],
        ),
      ),
      contentPadding: EdgeInsets.fromLTRB(24, 24, 24, 0),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(str.alertCancel.toUpperCase()),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_controller.text);
          },
          child: Text(str.alertOk.toUpperCase()),
        ),
      ],
    );
  }
}
