import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/cubit/autocomplete_cubit.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/cubit/filter_cubit.dart';
import 'package:keevault/cubit/sort_cubit.dart';
import 'package:keevault/logging/logger.dart';
import 'package:keevault/model/entry.dart';
import 'package:keevault/widgets/entry.dart';
import 'package:keevault/widgets/in_app_messenger.dart';
import 'package:keevault/autofill_matching.dart';
import 'package:keevault/widgets/autofill_match_badge.dart';
import 'package:keevault/widgets/autofill_target_card.dart';
import '../config/app.dart';
import '../config/routes.dart';
import '../cubit/account_cubit.dart';
import '../cubit/interaction_cubit.dart';
import '../cubit/vault_cubit.dart';
import 'package:animations/animations.dart';
import 'package:collection/collection.dart';
import 'loading_spinner.dart';
import 'package:keevault/extension_methods.dart';
import 'package:keevault/generated/l10n.dart';
import 'dialog_utils.dart';

/// Rebuild the list only when the request or its matches change, not for every state change (e.g. the "also link" switch)
bool _autofillListNeedsRebuild(AutofillState previous, AutofillState current) {
  if (previous is AutofillRequested && current is AutofillRequested) {
    return previous.target != current.target || previous.matches != current.matches;
  }
  return previous.runtimeType != current.runtimeType;
}

class EntryListWidget extends StatelessWidget {
  const EntryListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AutofillCubit, AutofillState>(
      buildWhen: _autofillListNeedsRebuild,
      builder: (context, autofillState) => BlocBuilder<SortCubit, SortState>(
        builder: (context, state) {
          final comparator = (state as SortedState).comparator;
          return BlocBuilder<FilterCubit, FilterState>(
            builder: (context, filterState) {
              final str = S.of(context);
              final List<Widget> listItems = [];
              listItems.add(EntryListHeaderWidget());

              if (filterState is FilterActive) {
                final filterCubit = BlocProvider.of<FilterCubit>(context);
                final vaultCubit = BlocProvider.of<VaultCubit>(context);
                final group = vaultCubit.findGroupByUuidOrRoot(filterState.groupUuid);
                final entries = filterState.includeChildGroups
                    ? group.getAllEntriesExceptBin().values
                    : group.entries.values;

                // This won't catch every case where there are no entries in the Vault
                // but will work for the most important (first-time view of a new KDBX file) and is fast.
                final emptyVault =
                    entries.isEmpty &&
                    filterState.groupUuid == filterState.rootGroupUuid &&
                    filterState.includeChildGroups;
                if (emptyVault) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(str.noEntriesCreateNewInstruction, style: Theme.of(context).textTheme.bodyLarge),
                      ),
                      OutlinedButton(
                        child: Text(str.import),
                        onPressed: () async => await AppConfig.router.navigateTo(context, Routes.importExport),
                      ),
                    ],
                  );
                }

                final sortedEntries = entries.where((entry) => filterCubit.entryMatches(entry)).sorted(comparator);

                if (autofillState is AutofillRequested) {
                  listItems.addAll(_buildAutofillSections(context, str, autofillState, sortedEntries));
                } else {
                  // Normal mode - just show all entries
                  listItems.addAll(sortedEntries.map((e) => EntryListItemWidget(uuid: e.uuid.uuid)));
                }
              }
              return ListView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, children: listItems);
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildAutofillSections(
    BuildContext context,
    S str,
    AutofillRequested autofillState,
    List<KdbxEntry> sortedEntries,
  ) {
    final theme = Theme.of(context);
    final target = autofillState.target;
    final matches = autofillState.matches ?? AutofillMatches.empty;
    final targetName = target.displayName ?? str.autofillUnknownTarget;

    // Entries arrive in the user's sort order. Matches are then ordered by tier, keeping that order within a tier.
    final matchedEntries = sortedEntries.where((e) => matches[e.uuid.uuid] != null).toList();
    mergeSort(
      matchedEntries,
      compare: (a, b) => matches[a.uuid.uuid]!.tier.index.compareTo(matches[b.uuid.uuid]!.tier.index),
    );
    final otherEntries = sortedEntries.where((e) => matches[e.uuid.uuid] == null).toList();

    final items = <Widget>[];
    if (matchedEntries.isNotEmpty) {
      items.add(_buildSectionHeader(theme, str.autofillMatchesHeader(targetName, matchedEntries.length)));
      items.addAll(matchedEntries.map((e) => EntryListItemWidget(uuid: e.uuid.uuid)));
      items.add(_buildSectionSeparator());
    } else if (!matches.isEmpty) {
      items.add(_buildMutedLine(theme, str.autofillMatchesHiddenBySearch));
    } else {
      items.add(_buildMutedLine(theme, str.autofillNoMatches(targetName)));
    }

    if (otherEntries.isNotEmpty) {
      items.add(
        _buildSectionHeader(
          theme,
          str.autofillOtherEntries,
          helper: target.hasVerifiedSignal
              ? str.autofillOtherEntriesLinkedHint(targetName)
              : str.autofillOtherEntriesCautionHint(targetName),
        ),
      );
      items.addAll(otherEntries.map((e) => EntryListItemWidget(uuid: e.uuid.uuid)));
    }
    return items;
  }

  Widget _buildSectionHeader(ThemeData theme, String title, {String? helper}) {
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: color),
          ),
          if (helper != null) Text(helper, style: theme.textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildMutedLine(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }

  Widget _buildSectionSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Divider(thickness: 2, height: 1),
    );
  }
}

/// The target card and any warnings about it, shown above the list while choosing an entry to autofill
class EntryListHeaderWidget extends StatelessWidget {
  const EntryListHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AutofillCubit, AutofillState>(
      builder: (context, state) {
        if (state is! AutofillRequested) return const SizedBox.shrink();
        return Column(
          children: [
            AutofillTargetCard(state: state),
            AutofillConcernBanners(
              target: state.target,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            ),
          ],
        );
      },
    );
  }
}

class EntryListItemWidget extends StatelessWidget {
  final String uuid;
  const EntryListItemWidget({super.key, required this.uuid});

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return BlocBuilder<VaultCubit, VaultState>(
      builder: (context, vaultState) {
        final loadedState = vaultState;
        if (loadedState is VaultLoaded) {
          final vaultCubit = BlocProvider.of<VaultCubit>(context);

          // Although we might move it to other groups, the reference to the underlying
          // kdbxentry never changes so we don't have to track it as state
          final entry = vaultCubit.findEntryByUuid(uuid);

          if (entry != null && vaultCubit.currentVaultFile != null) {
            var entryListItemVM = EntryListItemViewModel(entry);
            return BlocBuilder<AutofillCubit, AutofillState>(
              buildWhen: _autofillListNeedsRebuild,
              builder: (context, autoFillState) {
                if (autoFillState is AutofillRequested) {
                  final match = autoFillState.matches?[uuid];
                  return ListTile(
                    key: ValueKey('autofill$uuid'),
                    title: Text(entryListItemVM.label),
                    isThreeLine: true,
                    subtitle: Text('${entryListItemVM.username}\n${entryListItemVM.domain ?? ''}'),
                    leading: entryListItemVM.getIcon(32, Theme.of(context).brightness == Brightness.dark),
                    trailing: match != null ? AutofillMatchBadge(match: match, target: autoFillState.target) : null,
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      final autofillCubit = BlocProvider.of<AutofillCubit>(context);
                      if (autoFillState.target.requiresConfirmation) {
                        final confirmed = await DialogUtils.showConfirmDialog(
                          context: context,
                          params: ConfirmDialogParams(
                            title: str.autofillConfirmUnverifiedTitle,
                            content: str.autofillConfirmUnverifiedBody,
                            positiveButtonText: str.alertOk,
                            negativeButtonText: str.alertCancel,
                          ),
                        );
                        if (!confirmed || !context.mounted) return;
                      }

                      // We may display a loading spinner if the autofill process takes
                      // long enough for the dialog to render but in many cases we'll
                      // be fast enough that it's won't finish animating in to view.
                      unawaited(
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => PopScope(
                            canPop: false,
                            child: Center(
                              child: SizedBox(width: 48, height: 48, child: LoadingSpinner(tooltip: str.autofilling)),
                            ),
                          ),
                        ),
                      );

                      try {
                        // The switch can change after this tile was built so read the latest value
                        final latest = autofillCubit.state;
                        await autofillCubit.fillWithEntry(
                          entry,
                          vaultCubit,
                          linkUnverifiedDomain: latest is AutofillRequested && latest.linkUnverifiedDomain,
                        );
                      } finally {
                        // The plugin finishes the activity so this only clears the spinner if it is still alive
                        navigator.pop();
                      }
                    },
                  );
                } else {
                  return OpenContainer<bool>(
                    key: ValueKey(uuid),
                    tappable: false,
                    closedShape: RoundedRectangleBorder(),
                    closedElevation: 0,
                    closedColor: Colors.transparent,
                    transitionType: ContainerTransitionType.fade,
                    transitionDuration: const Duration(milliseconds: 300),
                    openBuilder: (context, close) {
                      return EntryWidget(
                        savingViaAutofill: false,
                        key: ValueKey('details'),
                        endEditing: (bool keepChanges) {
                          close(returnValue: keepChanges);
                        },
                        onDelete: () {
                          close(returnValue: false);
                          if (entry.isInRecycleBin) {
                            entry.file!.deleteEntry(entry, true);
                          } else {
                            entry.file!.deleteEntry(entry);
                          }
                          vaultCubit.reemitLoadedState();
                        },
                        allCustomIcons: entry.file!.body.meta.customIcons.map(
                          (key, value) => MapEntry(
                            value,
                            Image.memory(value.data, fit: BoxFit.contain, filterQuality: FilterQuality.low),
                          ),
                        ),
                        revertTo: (int index) {
                          final entryCubit = BlocProvider.of<EntryCubit>(context);
                          entryCubit.revertToHistoryEntry(entry, index);
                          final filterCubit = BlocProvider.of<FilterCubit>(context);
                          filterCubit.reFilter(entry.file!.trimmedTags, entry.file!.body.rootGroup);
                          close(returnValue: false);
                          //TODO:f: Maybe one day we can automatically reopen the container with the updated information?
                          //   BlocProvider.of<EntryCubit>(context).startEditing(entry);
                          // open();
                        },
                        deleteAt: (int index) {
                          final entryCubit = BlocProvider.of<EntryCubit>(context);
                          entryCubit.removeHistoryEntry(entry, index);
                          final filterCubit = BlocProvider.of<FilterCubit>(context);
                          filterCubit.reFilter(entry.file!.trimmedTags, entry.file!.body.rootGroup);
                          close(returnValue: false);
                        },
                      );
                    },
                    onClosed: (bool? keepChanges) async {
                      if (!context.mounted) {
                        l.e(
                          "context not mounted so we can't tidy up or save the entry. Presumably something happened to make the underlying Vault go away, such as autofill save entry screen replacing the main vault.",
                        );
                        return;
                      }
                      final entryCubit = BlocProvider.of<EntryCubit>(context);
                      final iam = InAppMessengerWidget.of(context);
                      if ((keepChanges == null || keepChanges) && (entryCubit.state as EntryLoaded).entry.isDirty) {
                        entryCubit.endEditing(entry);
                        final filterCubit = BlocProvider.of<FilterCubit>(context);
                        final autocompleteCubit = BlocProvider.of<AutocompleteCubit>(context);
                        await BlocProvider.of<InteractionCubit>(context).entrySaved();
                        autocompleteCubit.addUsername(entry.getString(KdbxKeyCommon.USER_NAME)?.getText().trim() ?? '');
                        await iam.showIfAppropriate(InAppMessageTrigger.entryChanged);
                        filterCubit.reFilter(entry.file!.trimmedTags, entry.file!.body.rootGroup);
                        //TODO:f: A separate cubit to track state of ELIVMs might provide better performance and scroll position stability than recreating them all from scratch every time we re-filter?
                      } else {
                        entryCubit.endEditing(null);
                        await vaultCubit.applyPendingChangesIfSafe(
                          BlocProvider.of<AccountCubit>(context).currentUserIfKnown,
                        );
                        await iam.showIfAppropriate(InAppMessageTrigger.entryUnchanged);
                      }
                    },
                    closedBuilder: (context, open) {
                      final url = entryListItemVM.website;
                      return ListTile(
                        key: ValueKey('summary$uuid'),
                        title: Text(entryListItemVM.label),
                        isThreeLine: true,
                        subtitle: Text('${entryListItemVM.username}\n${entryListItemVM.domain ?? ''}'),
                        leading: entryListItemVM.getIcon(32, Theme.of(context).brightness == Brightness.dark),
                        trailing: url != null
                            ? IconButton(
                                icon: Icon(Icons.open_in_new),
                                onPressed: () async {
                                  await DialogUtils.openUrl(url);
                                },
                              )
                            : null,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          BlocProvider.of<EntryCubit>(context).startEditing(entry);
                          open();
                        },
                      );
                    },
                  );
                }
              },
            );
          }
        }
        return ListTile(
          title: Text(str.openError),
          subtitle: Text('Entry missing. Please close and re-launch the app.'),
        );
      },
    );
  }
}
