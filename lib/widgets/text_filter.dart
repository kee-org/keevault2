import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/cubit/filter_cubit.dart';
import 'package:keevault/generated/l10n.dart';

class TextFilterWidget extends StatelessWidget {
  const TextFilterWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<FilterCubit, FilterState>(
      builder: (context, state) {
        if (state is! FilterActive) return Container();
        final filterState = state;
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(str.searchSearchIn),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16.0),
                            child: Wrap(
                              spacing: 16.0,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              alignment: WrapAlignment.center,
                              runSpacing: 4.0,
                              children: [
                                FilterChip(
                                  visualDensity: VisualDensity.standard,
                                  label: Text(str.sortTitle),
                                  avatar: filterState.textOptions.title
                                      ? Icon(
                                          Icons.check,
                                          size: 18,
                                        )
                                      : SizedBox(width: 24),
                                  labelPadding: EdgeInsets.only(left: 2, right: 12),
                                  showCheckmark: false,
                                  selected: filterState.textOptions.title,
                                  onSelected: (bool value) {
                                    final cubit = BlocProvider.of<FilterCubit>(context);
                                    cubit.updateTextOptions(filterState.textOptions.copyWith(title: value));
                                  },
                                ),
                                FilterChip(
                                  visualDensity: VisualDensity.standard,
                                  label: Text(str.userEmail),
                                  avatar: filterState.textOptions.username
                                      ? Icon(
                                          Icons.check,
                                          size: 18,
                                        )
                                      : SizedBox(width: 24),
                                  labelPadding: EdgeInsets.only(left: 2, right: 12),
                                  showCheckmark: false,
                                  selected: filterState.textOptions.username,
                                  onSelected: (bool value) {
                                    final cubit = BlocProvider.of<FilterCubit>(context);
                                    cubit.updateTextOptions(filterState.textOptions.copyWith(username: value));
                                  },
                                ),
                                FilterChip(
                                  visualDensity: VisualDensity.standard,
                                  label: Text(str.website),
                                  avatar: filterState.textOptions.urls
                                      ? Icon(
                                          Icons.check,
                                          size: 18,
                                        )
                                      : SizedBox(width: 24),
                                  labelPadding: EdgeInsets.only(left: 2, right: 12),
                                  showCheckmark: false,
                                  selected: filterState.textOptions.urls,
                                  onSelected: (bool value) {
                                    final cubit = BlocProvider.of<FilterCubit>(context);
                                    cubit.updateTextOptions(filterState.textOptions.copyWith(urls: value));
                                  },
                                ),
                                FilterChip(
                                  visualDensity: VisualDensity.standard,
                                  label: Text(str.password),
                                  avatar: filterState.textOptions.password
                                      ? Icon(
                                          Icons.check,
                                          size: 18,
                                        )
                                      : SizedBox(width: 24),
                                  labelPadding: EdgeInsets.only(left: 2, right: 12),
                                  showCheckmark: false,
                                  selected: filterState.textOptions.password,
                                  onSelected: (bool value) {
                                    final cubit = BlocProvider.of<FilterCubit>(context);
                                    cubit.updateTextOptions(filterState.textOptions.copyWith(password: value));
                                  },
                                ),
                                FilterChip(
                                  visualDensity: VisualDensity.standard,
                                  label: Text(str.notes),
                                  avatar: filterState.textOptions.notes
                                      ? Icon(
                                          Icons.check,
                                          size: 18,
                                        )
                                      : SizedBox(width: 24),
                                  labelPadding: EdgeInsets.only(left: 2, right: 12),
                                  showCheckmark: false,
                                  selected: filterState.textOptions.notes,
                                  onSelected: (bool value) {
                                    final cubit = BlocProvider.of<FilterCubit>(context);
                                    cubit.updateTextOptions(filterState.textOptions.copyWith(notes: value));
                                  },
                                ),
                                FilterChip(
                                  visualDensity: VisualDensity.standard,
                                  label: Text(str.searchOtherStandard),
                                  avatar: filterState.textOptions.other
                                      ? Icon(
                                          Icons.check,
                                          size: 18,
                                        )
                                      : SizedBox(width: 24),
                                  labelPadding: EdgeInsets.only(left: 2, right: 12),
                                  showCheckmark: false,
                                  selected: filterState.textOptions.other,
                                  onSelected: (bool value) {
                                    final cubit = BlocProvider.of<FilterCubit>(context);
                                    cubit.updateTextOptions(filterState.textOptions.copyWith(other: value));
                                  },
                                ),
                                FilterChip(
                                  visualDensity: VisualDensity.standard,
                                  label: Text(str.searchOtherSecure),
                                  avatar: filterState.textOptions.otherProtected
                                      ? Icon(
                                          Icons.check,
                                          size: 18,
                                        )
                                      : SizedBox(width: 24),
                                  labelPadding: EdgeInsets.only(left: 2, right: 12),
                                  showCheckmark: false,
                                  selected: filterState.textOptions.otherProtected,
                                  onSelected: (bool value) {
                                    final cubit = BlocProvider.of<FilterCubit>(context);
                                    cubit.updateTextOptions(filterState.textOptions.copyWith(otherProtected: value));
                                  },
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(0.0),
                            child: Column(children: [
                              ListTile(
                                title: Text(str.searchCase),
                                leading: Switch(
                                    value: filterState.textOptions.caseSensitive,
                                    onChanged: (bool value) {
                                      final cubit = BlocProvider.of<FilterCubit>(context);
                                      cubit.updateTextOptions(filterState.textOptions.copyWith(caseSensitive: value));
                                    }),
                              ),
                              ListTile(
                                title: Text(str.searchHistory),
                                leading: Switch(
                                    value: filterState.textOptions.history,
                                    onChanged: (bool value) {
                                      final cubit = BlocProvider.of<FilterCubit>(context);
                                      cubit.updateTextOptions(filterState.textOptions.copyWith(history: value));
                                    }),
                              ),
                              ListTile(
                                title: Text(str.searchRegex),
                                leading: Switch(
                                    value: filterState.textOptions.regex,
                                    onChanged: (bool value) {
                                      final cubit = BlocProvider.of<FilterCubit>(context);
                                      cubit.updateTextOptions(filterState.textOptions.copyWith(regex: value));
                                    }),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8.0, left: 8, right: 16),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(
                      Icons.info,
                      color: theme.textTheme.bodySmall!.color,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      str.textFilteringHint,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
