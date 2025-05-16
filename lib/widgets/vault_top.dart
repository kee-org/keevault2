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
  );
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
