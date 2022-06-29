import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/widgets/editable_list.dart';
import '../generated/l10n.dart';

class IntegrationSettingsWidget extends StatefulWidget {
  const IntegrationSettingsWidget({
    Key? key,
  }) : super(key: key);

  @override
  State<IntegrationSettingsWidget> createState() => _IntegrationSettingsWidgetState();
}

class _IntegrationSettingsWidgetState extends State<IntegrationSettingsWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return BlocBuilder<EntryCubit, EntryState>(builder: (context, state) {
      final entry = (state as EntryLoaded).entry;
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
              headerBuilder: (context, isExpanded) => ListTile(
                title: Text(str.integrationSettings),
              ),
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(str.integrationSettingsExplainer),
                    ),
                    Divider(
                      indent: 16,
                      endIndent: 16,
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ListTile(
                            title: Text(str.showEntryInBrowsersAndApps),
                            leading: Switch(
                              value: !entry.browserSettings.hide,
                              onChanged: (bool? value) {
                                if (value != null) {
                                  final cubit = BlocProvider.of<EntryCubit>(context);
                                  cubit.update(browserSettings: entry.browserSettings.copyWith(hide: !value));
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(
                      indent: 16,
                      endIndent: 16,
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: EditableListWidget<String>(
                            hint: str.entryIntegrationHintNewUrl,
                            title: str.additionalUrlsToMatch,
                            items: entry.browserSettings.includeUrls
                                .whereType<String>()
                                .cast<String>()
                                .map((s) => s.toLowerCase())
                                .toList(growable: false),
                            onAddFromString: (String value) {
                              final cubit = BlocProvider.of<EntryCubit>(context);
                              cubit.update(
                                  browserSettings: entry.browserSettings
                                      .copyWith(includeUrls: [...entry.browserSettings.includeUrls, value]));
                              return true;
                            },
                            onRemove: (String value) {
                              final cubit = BlocProvider.of<EntryCubit>(context);
                              cubit.update(
                                  browserSettings: entry.browserSettings.copyWith(
                                      includeUrls: entry.browserSettings.includeUrls
                                          .where((url) => url is! String || url != value)
                                          .toList()));
                            },
                          ),
                        ),
                      ],
                    ),
                    Divider(
                      indent: 16,
                      endIndent: 16,
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                            child: MatchAccuracyRadioWidget(
                          minimumMatchAccuracy: entry.browserSettings.minimumMatchAccuracy,
                        )),
                      ],
                    ),
                    Divider(
                      indent: 16,
                      endIndent: 16,
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: EditableListWidget<String>(
                            hint: str.entryIntegrationHintNewId,
                            title: str.androidAppIdsToMatch,
                            items: entry.androidPackageNames.map((s) => s.toLowerCase()).toList(growable: false),
                            onAddFromString: (String value) {
                              final cubit = BlocProvider.of<EntryCubit>(context);
                              cubit.update(androidPackageNames: [...entry.androidPackageNames, value]);
                              return true;
                            },
                            onRemove: (String value) {
                              final cubit = BlocProvider.of<EntryCubit>(context);
                              cubit.update(
                                  androidPackageNames: entry.androidPackageNames.where((i) => i != value).toList());
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class MatchAccuracyRadioWidget extends StatefulWidget {
  final MatchAccuracy minimumMatchAccuracy;
  const MatchAccuracyRadioWidget({Key? key, required this.minimumMatchAccuracy}) : super(key: key);

  @override
  State<MatchAccuracyRadioWidget> createState() => _MatchAccuracyRadioWidgetState();
}

class _MatchAccuracyRadioWidgetState extends State<MatchAccuracyRadioWidget> with SingleTickerProviderStateMixin {
  void onChanged(MatchAccuracy? value) {
    if (value != null) {
      final cubit = BlocProvider.of<EntryCubit>(context);
      cubit.update(
          browserSettings: (cubit.state as EntryLoaded).entry.browserSettings.copyWith(minimumMatchAccuracy: value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          str.minURLMatchAccuracy,
          style: theme.textTheme.subtitle1,
        ),
        Tooltip(
          message: str.minimumMatchAccuracyDomainExplainer,
          child: RadioListTile<MatchAccuracy>(
            title: Text(str.domain),
            value: MatchAccuracy.Domain,
            groupValue: widget.minimumMatchAccuracy,
            onChanged: onChanged,
          ),
        ),
        Tooltip(
          message: str.minimumMatchAccuracyHostnameExplainer,
          child: RadioListTile<MatchAccuracy>(
            title: Text(str.hostname),
            value: MatchAccuracy.Hostname,
            groupValue: widget.minimumMatchAccuracy,
            onChanged: onChanged,
          ),
        ),
        Tooltip(
          message: str.minimumMatchAccuracyExactExplainer,
          child: RadioListTile<MatchAccuracy>(
            title: Text(str.exact),
            value: MatchAccuracy.Exact,
            groupValue: widget.minimumMatchAccuracy,
            onChanged: onChanged,
          ),
        ),
        AnimatedSize(
          duration: Duration(milliseconds: 750),
          child: SizedBox(
            height: widget.minimumMatchAccuracy == MatchAccuracy.Exact ? null : 0.0,
            child: Text(str.minURLMatchAccuracyExactWarning),
          ),
        ),
      ],
    );
  }
}
