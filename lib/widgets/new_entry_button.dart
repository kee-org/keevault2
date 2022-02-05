import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/cubit/filter_cubit.dart';
import '../generated/l10n.dart';

import 'entry.dart';

class NewEntryButton extends StatelessWidget {
  final KdbxFile currentFile;

  const NewEntryButton({Key? key, required this.currentFile}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return BlocBuilder<AutofillCubit, AutofillState>(builder: (context, autoFillState) {
      if (autoFillState is! AutofillRequested) {
        return Visibility(
          visible: MediaQuery.of(context).viewInsets.bottom <= 0.0,
          child: OpenContainer<bool>(
            key: ValueKey('new entry screen'),
            tappable: false,
            closedShape: CircleBorder(),
            closedElevation: 0,
            closedColor: Colors.transparent,
            transitionType: ContainerTransitionType.fade,
            transitionDuration: const Duration(milliseconds: 300),
            openBuilder: (context, close) {
              return EntryWidget(
                key: ValueKey('details'),
                endEditing: (bool keepChanges) {
                  close(returnValue: keepChanges);
                },
                allCustomIcons: currentFile.body.meta.customIcons.map((key, value) => MapEntry(
                      value,
                      Image.memory(
                        value.data,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.low,
                      ),
                    )),
                revertTo: (int index) {},
                deleteAt: (int index) {},
              );
            },
            onClosed: (bool? keepChanges) {
              final entryCubit = BlocProvider.of<EntryCubit>(context);
              if ((keepChanges == null || keepChanges) && (entryCubit.state as EntryLoaded).entry.isDirty) {
                entryCubit.endCreating(currentFile);
                final filterCubit = BlocProvider.of<FilterCubit>(context);
                filterCubit.reFilter(currentFile.tags);
              } else {
                entryCubit.endCreating(null);
              }
            },
            closedBuilder: (context, open) {
              return FloatingActionButton(
                child: Icon(Icons.add),
                tooltip: str.createNewEntry,
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  BlocProvider.of<EntryCubit>(context).startCreating(currentFile);
                  open();
                },
              );
            },
          ),
        );
      }
      return SizedBox();
    });
  }
}
