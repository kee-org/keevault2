import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/cubit/filter_cubit.dart';
import 'package:keevault/cubit/sort_cubit.dart';
import '../generated/l10n.dart';

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return TextField(
      maxLength: null,
      minLines: 1,
      maxLines: 1,
      autocorrect: false,
      autofillHints: null,
      enableSuggestions: false,
      expands: false,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        suffixIcon: Icon(Icons.search, semanticLabel: 'search'),
        isDense: true,
        errorMaxLines: 0,
        helperMaxLines: 0,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        filled: true,
        hintText: str.search,
        hintMaxLines: 1,
      ),
      onChanged: (String value) {
        BlocProvider.of<FilterCubit>(context).changeText(value);
      },
    );
  }
}

AppBar vaultTopBarWidget(BuildContext context) {
  final str = S.of(context);
  final sortCubit = BlocProvider.of<SortCubit>(context);
  return AppBar(
    automaticallyImplyLeading: false,
    leading: ShowFilterWidget(str: str),
    actions: [
      PopupMenuButton(
        icon: Icon(Icons.sort),
        itemBuilder: (BuildContext context) {
          final currentMode = (sortCubit.state is SortedState) ? (sortCubit.state as SortedState).mode : null;
          final navigator = Navigator.of(context);
          return <PopupMenuEntry>[
            PopupMenuItem(
              child: ListTile(
                trailing: currentMode == SortMode.titleAsc ? Icon(Icons.done) : null,
                title: Text(str.sortTitle),
                onTap: () async {
                  await sortCubit.reorder(SortMode.titleAsc);
                  navigator.pop();
                },
              ),
            ),
            PopupMenuItem(
              child: ListTile(
                trailing: currentMode == SortMode.titleDesc ? Icon(Icons.done) : null,
                title: Text(str.sortTitleReversed),
                onTap: () async {
                  await sortCubit.reorder(SortMode.titleDesc);
                  navigator.pop();
                },
              ),
            ),
            PopupMenuItem(
              child: ListTile(
                trailing: currentMode == SortMode.modifiedDesc ? Icon(Icons.done) : null,
                title: Text(str.sortModified),
                onTap: () async {
                  await sortCubit.reorder(SortMode.modifiedDesc);
                  navigator.pop();
                },
              ),
            ),
            PopupMenuItem(
              child: ListTile(
                trailing: currentMode == SortMode.modifiedAsc ? Icon(Icons.done) : null,
                title: Text(str.sortModifiedReversed),
                onTap: () async {
                  await sortCubit.reorder(SortMode.modifiedAsc);
                  navigator.pop();
                },
              ),
            ),
            PopupMenuItem(
              child: ListTile(
                trailing: currentMode == SortMode.createdDesc ? Icon(Icons.done) : null,
                title: Text(str.sortCreated),
                onTap: () async {
                  await sortCubit.reorder(SortMode.createdDesc);
                  navigator.pop();
                },
              ),
            ),
            PopupMenuItem(
              child: ListTile(
                trailing: currentMode == SortMode.createdAsc ? Icon(Icons.done) : null,
                title: Text(str.sortCreatedReversed),
                onTap: () async {
                  await sortCubit.reorder(SortMode.createdAsc);
                  navigator.pop();
                },
              ),
            ),
          ];
        },
      ),
    ],
    titleSpacing: 8.0,
    title: _SearchBar(),
    bottom: PreferredSize(
      preferredSize: Size.fromHeight(48.0),
      child: BlocBuilder<FilterCubit, FilterState>(
        builder: (context, state) {
          final theme = Theme.of(context);
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  height: 48.0,
                  width: double.infinity,
                  alignment: AlignmentDirectional.centerStart,
                  child: DefaultTextStyle(
                    style: TextStyle(color: theme.hintColor),
                    child: Text(_generateTitle(context, state)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

String _generateTitle(BuildContext context, FilterState state) {
  final str = S.of(context);

  if (state is FilterActive) {
    final bool text = state.text.isNotEmpty;
    final bool group = state.groupUuid != state.rootGroupUuid;
    final bool tag = state.tags.isNotEmpty;
    final bool color = state.colors.isNotEmpty;

    if (!text && !group && !tag && !color) {
      return str.showing_all_entries;
    } else {
      final criteria = [
        if (group) str.group,
        if (text) str.text.toLowerCase(),
        if (tag && state.tags.length > 1) str.labels.toLowerCase(),
        if (tag && state.tags.length == 1) str.label.toLowerCase(),
        if (color && state.colors.length > 1) str.colors.toLowerCase(),
        if (color && state.colors.length == 1) str.color.toLowerCase(),
      ];
      return str.filteredByCriteria(
        criteria.length > 2
            ? '${criteria.getRange(0, criteria.length - 1).join(', ')} and ${criteria.last}'
            : criteria.join(' and '),
      );
    }
  }
  return str.loading;
}

class ShowFilterWidget extends StatelessWidget {
  const ShowFilterWidget({super.key, required this.str});

  final S str;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.filter_alt),
      tooltip: str.filterTooltipClosed,
      onPressed: () => Scaffold.of(context).openDrawer(),
    );
  }
}
