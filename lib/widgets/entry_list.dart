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
import 'package:flutter_autofill_service/flutter_autofill_service.dart' show AutofillMetadata;
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

class EntryListWidget extends StatelessWidget {
  const EntryListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SortCubit, SortState>(
      builder: (context, state) {
        final comparator = (state as SortedState).comparator;
        return BlocBuilder<FilterCubit, FilterState>(
          builder: (context, filterState) {
            final str = S.of(context);
            final List<Widget> listItems = [];
            listItems.add(EntryListHeaderWidget());

            // Check if we're in autofill mode to potentially show matching entries
            final autofillState = BlocProvider.of<AutofillCubit>(context).state;
            final bool isAutofillMode = autofillState is AutofillRequested;

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

              if (isAutofillMode) {
                final autofillRequested = autofillState;
                final matchingEntries = _findMatchingEntries(
                  autofillRequested.androidMetadata,
                  sortedEntries,
                  vaultCubit,
                );
                final matchingUuids = matchingEntries.map((e) => e.uuid.uuid).toSet();
                final nonMatchingEntries = sortedEntries.where((e) => !matchingUuids.contains(e.uuid.uuid)).toList();

                if (matchingEntries.isNotEmpty) {
                  listItems.add(_buildSectionHeader(str.autofillMatchingEntries));
                  listItems.addAll(matchingEntries.map((e) => EntryListItemWidget(uuid: e.uuid.uuid)));
                  listItems.add(_buildSectionSeparator());
                }

                if (nonMatchingEntries.isNotEmpty) {
                  listItems.add(_buildSectionHeader(str.autofillAllEntries));
                  listItems.addAll(nonMatchingEntries.map((e) => EntryListItemWidget(uuid: e.uuid.uuid)));
                }
              } else {
                // Normal mode - just show all entries
                listItems.addAll(sortedEntries.map((e) => EntryListItemWidget(uuid: e.uuid.uuid)));
              }
            }
            return ListView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, children: listItems);
          },
        );
      },
    );
  }

  // Find entries that match the autofill request (by appId or domain)
  // Uses shared logic from AutofillCubit to ensure consistency with automatic autofill
  List<KdbxEntry> _findMatchingEntries(AutofillMetadata metadata, List<KdbxEntry> entries, VaultCubit vaultCubit) {
    return AutofillCubit.findMatchingEntries(metadata, entries, vaultCubit.currentVaultFile?.files.current);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
      ),
    );
  }

  Widget _buildSectionSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Divider(thickness: 2, height: 1),
    );
  }
}

class EntryListHeaderWidget extends StatelessWidget {
  const EntryListHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AutofillCubit, AutofillState>(
      builder: (context, state) {
        if (state is AutofillRequested) {
          final theme = Theme.of(context);
          final str = S.of(context);
          final String appId = (state.androidMetadata.appId?.isNotEmpty ?? false) ? state.androidMetadata.appId! : '';
          final webDomain = state.androidMetadata.webDomains.isNotEmpty
              ? state.androidMetadata.webDomains.first.domain
              : '';

          final messageTarget = [
            TextSpan(text: 'Select an entry to fill into ', style: theme.textTheme.bodyMedium),
            webDomain != ''
                ? TextSpan(
                    text: webDomain,
                    style: theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
                  )
                : TextSpan(text: 'the app described below', style: theme.textTheme.bodyMedium),
            TextSpan(text: '.', style: theme.textTheme.bodyMedium),
          ];
          final messageOutcome = TextSpan(
            text: state.forceInteractive
                ? " We'll add it to the list of matches for this ${webDomain != '' ? 'site' : 'app'}."
                : " We'll remember next time.",
            style: theme.textTheme.bodyMedium,
          );

          final message = RichText(text: TextSpan(children: <TextSpan>[...messageTarget, messageOutcome]));

          //TODO:f skip subtitle for known browser IDs
          final subTitle = appId.isNotEmpty ? Text('Filling into this app: $appId') : null;

          final List<Widget> headerWidgets = [];

          // Warning 1: App is not a known official app or browser
          if (webDomain.isNotEmpty && !state.androidMetadata.dalVerified) {
            headerWidgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.error, width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          str.autofillWarningNotOfficialApp,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Warning 2: App ID is not trusted
          if (appId.isNotEmpty && !state.androidMetadata.appIdTrusted) {
            headerWidgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.error, width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          str.autofillWarningAppIdNotTrusted,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          headerWidgets.add(
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ListTile(
                tileColor: theme.brightness == Brightness.dark
                    ? Colors.deepOrange.shade900
                    : Colors.deepOrange.shade100,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                title: Padding(padding: EdgeInsets.only(bottom: 10), child: message),
                subtitle: subTitle,
              ),
            ),
          );

          return Column(children: headerWidgets);
        } else {
          return SizedBox.shrink();
        }
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
              builder: (context, autoFillState) {
                if (autoFillState is AutofillRequested) {
                  final autofillCubit = BlocProvider.of<AutofillCubit>(context);
                  return ListTile(
                    key: ValueKey('autofill$uuid'),
                    title: Text(entryListItemVM.label),
                    isThreeLine: true,
                    subtitle: Text('${entryListItemVM.username}\n${entryListItemVM.domain ?? ''}'),
                    leading: entryListItemVM.getIcon(32, Theme.of(context).brightness == Brightness.dark),
                    onTap: () async {
                      final navigator = Navigator.of(context);
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

                      // Save app id or domain for future matching purposes
                      final appId = autoFillState.androidMetadata.appId ?? '';
                      final webDomain = autoFillState.androidMetadata.webDomains.isNotEmpty
                          ? autoFillState.androidMetadata.webDomains.first.domain
                          : '';
                      final scheme = autoFillState.androidMetadata.webDomains.isNotEmpty
                          ? autoFillState.androidMetadata.webDomains.first.scheme
                          : null;

                      await vaultCubit.addAutofillPersistentQueueItem({
                        'domain': webDomain,
                        'scheme': scheme,
                        'entry': uuid,
                        'appId': appId,
                      });

                      // Android doesn't support returning a single result for automatic fill in response to
                      //the initial authentication request for matching entries. It's not ideal for the user but
                      // we can only return the single item as a list, for them to click on again to actually
                      // perform the fill they've asked for.
                      if (autoFillState.forceInteractive) {
                        autofillCubit.autofillInstantly(entry);
                      } else {
                        autofillCubit.autofillWithListOfOneEntry(entry);
                      }

                      navigator.pop();
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
