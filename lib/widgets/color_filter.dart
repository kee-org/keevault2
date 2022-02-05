import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/cubit/filter_cubit.dart';
import 'package:keevault/generated/l10n.dart';

import '../colors.dart';

class ColorFilterWidget extends StatelessWidget {
  const ColorFilterWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 96.0),
      child: BlocBuilder<FilterCubit, FilterState>(
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
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Wrap(
                            spacing: 16.0,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.center,
                            runSpacing: 16.0,
                            children: EntryColor.values
                                .map((c) => colorBlock(c, filterState.colors.contains(c), theme, context))
                                .toList(),
                          ),
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
                        color: theme.textTheme.caption!.color,
                      ),
                    ),
                    Expanded(
                        child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            str.colorsExplanation,
                            style: theme.textTheme.caption,
                          ),
                        ),
                        Text(
                          str.colorFilteringHint,
                          style: theme.textTheme.caption,
                        ),
                      ],
                    )),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget colorBlock(EntryColor c, bool isSelectedColor, ThemeData theme, BuildContext context) {
    final color = theme.brightness == Brightness.dark ? entryColorsContrast[c]! : entryColors[c]!;
    return Container(
      margin: EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.8),
            offset: Offset(1.0, 2.0),
            blurRadius: 2.0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => BlocProvider.of<FilterCubit>(context).toggleColor(c),
          borderRadius: BorderRadius.circular(24.0),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isSelectedColor ? 1.0 : 0.0,
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Icon(
                Icons.done_rounded,
                size: 64,
                color: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
