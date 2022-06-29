import 'package:flutter/material.dart';
import 'package:animate_icons/animate_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/cubit/filter_cubit.dart';
import 'package:keevault/cubit/sort_cubit.dart';
import '../colors.dart';
import '../generated/l10n.dart';

class _BackdropTitle extends StatelessWidget {
  const _BackdropTitle({
    Key? key,
    required Listenable listenable,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return SizedBox(
      height: 40,
      child: TextSelectionTheme(
        data: TextSelectionThemeData(
          cursorColor: AppPalettes.keeVaultPalette[50],
          selectionHandleColor: AppPalettes.keeVaultPalette[50],
          selectionColor: AppPalettes.keeVaultPalette[300],
        ),
        child: TextField(
          maxLength: null,
          minLines: 1,
          maxLines: 1,
          autocorrect: false,
          autofillHints: null,
          enableSuggestions: false,
          expands: false,
          textAlignVertical: TextAlignVertical.top,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: Colors.white, fontSize: 18.0),
          decoration: InputDecoration(
            suffixIcon: Icon(
              Icons.search,
              semanticLabel: 'search',
              color: Colors.white,
            ),
            isDense: true,
            errorMaxLines: 0,
            helperMaxLines: 0,
            floatingLabelBehavior: FloatingLabelBehavior.never,
            filled: true,
            fillColor: Color.fromRGBO(255, 255, 255, 0.1),
            hintText: str.search,
            hintStyle: const TextStyle(color: Colors.white60, fontSize: 18.0),
            hintMaxLines: 1,
          ),
          onChanged: (String value) {
            BlocProvider.of<FilterCubit>(context).changeText(value);
          },
        ),
      ),
    );
  }
}

AppBar vaultTopBarWidget(
  BuildContext context,
  AnimateIconController animatedIconController,
  AnimationController controller,
  Function toggleBackdropLayerVisibility,
  Color color,
) {
  final str = S.of(context);
  final sortCubit = BlocProvider.of<SortCubit>(context);
  return AppBar(
    automaticallyImplyLeading: false,
    elevation: 0.0,
    leading: IconButton(
      icon: AnimateIcons(
        startIcon: Icons.filter_alt,
        endIcon: Icons.done,
        controller: animatedIconController,
        size: 24.0,
        onStartIconPress: () {
          toggleBackdropLayerVisibility();
          return false;
        },
        onEndIconPress: () {
          toggleBackdropLayerVisibility();
          return false;
        },
        duration: Duration(milliseconds: 300),
        startIconColor: color,
        endIconColor: color,
        clockwise: true,
        startTooltip: str.filterTooltipClosed,
        endTooltip: str.filterTooltipOpen,
      ),
      onPressed: toggleBackdropLayerVisibility as void Function()?,
    ),
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
          })
    ],
    titleSpacing: 8.0,
    title: _BackdropTitle(
      listenable: controller.view,
    ),
  );
}
