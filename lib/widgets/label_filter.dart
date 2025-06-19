import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/cubit/filter_cubit.dart';
import 'package:keevault/cubit/vault_cubit.dart';
import 'package:keevault/generated/l10n.dart';

class LabelFilterWidget extends StatelessWidget {
  const LabelFilterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<VaultCubit, VaultState>(
      builder: (context, state) {
        if (state is! VaultLoaded) return Container();
        final vaultState = state;
        return BlocBuilder<FilterCubit, FilterState>(
          builder: (context, state) {
            if (state is! FilterActive) return Container();
            final filterState = state;
            return Visibility(
              visible: vaultState.vault.files.current.tags.isNotEmpty,
              replacement: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 8.0, right: 8.0),
                    child: Text(str.labelsExplanation, style: theme.textTheme.titleMedium),
                  ),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(str.labelsExplanation2)),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(str.labelAssignmentExplanation)),
                ],
              ),
              child: Column(
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
                                runSpacing: 8.0,
                                children: vaultState.vault.files.current.tags.map((tag) {
                                  final isSelected = filterState.tags.contains(tag.toLowerCase());
                                  return FilterChip(
                                    visualDensity: VisualDensity.standard,
                                    label: Text(tag),
                                    avatar: isSelected ? const Icon(Icons.check, size: 18) : const SizedBox(width: 24),
                                    labelPadding: const EdgeInsets.only(left: 2, right: 12),
                                    showCheckmark: false,
                                    selected: isSelected,
                                    onSelected: (bool _) {
                                      final cubit = BlocProvider.of<FilterCubit>(context);
                                      cubit.toggleTag(tag);
                                    },
                                  );
                                }).toList(),
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
                          child: Icon(Icons.info, color: theme.textTheme.bodySmall!.color),
                        ),
                        Expanded(child: Text(str.labelFilteringHint, style: theme.textTheme.bodySmall)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
