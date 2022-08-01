import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/cubit/account_cubit.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/cubit/filter_cubit.dart';
import 'package:keevault/cubit/vault_cubit.dart';
import 'package:keevault/extension_methods.dart';
import 'package:keevault/widgets/loading_spinner.dart';
import 'package:matomo/matomo.dart';
import 'entry.dart';

class AutofillSaveWidget extends TraceableStatefulWidget {
  const AutofillSaveWidget({
    super.key,
  });

  @override
  State<AutofillSaveWidget> createState() => _AutofillSaveWidgetState();
}

class _AutofillSaveWidgetState extends State<AutofillSaveWidget> {
  KdbxEntry? newEntry;
  @override
  void initState() {
    super.initState();
    final autofillState = BlocProvider.of<AutofillCubit>(context).state as AutofillModeActive;
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    final vault = vaultCubit.currentVaultFile;
    if (vault == null) {
      return;
    }
    final username = autofillState.androidMetadata.saveInfo!.username;
    final password = autofillState.androidMetadata.saveInfo!.password;
    //TODO:f: expose value of save compat mode to Entry widget:
    //final isCompatMode = autofillState.androidMetadata.saveInfo!.isCompatMode;
    setState(() {
      newEntry = vaultCubit.createEntry(group: vault.files.current.body.rootGroup);
    });

    final appId =
        autofillState.androidMetadata.packageNames.isNotEmpty ? autofillState.androidMetadata.packageNames.first : '';
    final webDomain = autofillState.androidMetadata.webDomains.isNotEmpty
        ? autofillState.androidMetadata.webDomains.first.domain
        : '';
    final scheme = autofillState.androidMetadata.webDomains.isNotEmpty
        ? autofillState.androidMetadata.webDomains.first.scheme
        : null;

    if (webDomain.isNotEmpty) {
      newEntry!.addAutofillUrl(webDomain, scheme);
      newEntry!.setString(KdbxKeyCommon.TITLE, PlainValue(webDomain));
    } else if (appId.isNotEmpty) {
      newEntry!.addAndroidPackageName(appId);
      newEntry!.setString(KdbxKeyCommon.TITLE, PlainValue(appId));
    } else {
      newEntry!.setString(KdbxKeyCommon.TITLE, PlainValue('[untitled]'));
    }

    username?.let((it) => newEntry!.setString(KdbxKeyCommon.USER_NAME, PlainValue(it)));
    password?.let((it) => newEntry!.setString(KdbxKeyCommon.PASSWORD, PlainValue(it)));
    BlocProvider.of<EntryCubit>(context).startEditing(newEntry!, startDirty: false);
  }

  onEndEditing(bool keepChanges, VaultCubit vaultCubit, List<String> tags) async {
    final entryCubit = BlocProvider.of<EntryCubit>(context);
    final autofillCubit = BlocProvider.of<AutofillCubit>(context);
    if (keepChanges && (entryCubit.state as EntryLoaded).entry.isDirty) {
      entryCubit.endEditing(newEntry);

      final filterCubit = BlocProvider.of<FilterCubit>(context);

      // We skip remote upload for now because it could take a long time
      // and interrupt the user's priority task for too long.
      await vaultCubit.save(
        BlocProvider.of<AccountCubit>(context).currentUserIfKnown,
        skipRemote: true,
      );

      // User may return to this Kee Vault instance in future and will
      // want the filter options to reflect any changes made while
      // adding this new entry
      filterCubit.reFilter(tags, vaultCubit.currentVaultFile!.files.current.body.rootGroup);
    } else {
      entryCubit.endEditing(null);

      // Save even without request to keep changes because the newly created
      // entry has yet to be saved.
      // We skip remote upload for now because it could take a long time
      // and interrupt the user's priority task for too long.
      await vaultCubit.save(
        BlocProvider.of<AccountCubit>(context).currentUserIfKnown,
        skipRemote: true,
      );
    }

    await autofillCubit.finishSaving();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntryCubit, EntryState>(
      builder: (context, state) {
        if (state is EntryLoaded) {
          final vaultCubit = BlocProvider.of<VaultCubit>(context);
          final vault = vaultCubit.currentVaultFile;
          if (vault == null) {
            throw Exception('Vault file missing');
          }
          return EntryWidget(
            key: ValueKey('autofillSaveDetails'),
            savingViaAutofill: true,
            endEditing: (bool keepChanges) => onEndEditing(keepChanges, vaultCubit, vault.files.current.tags),
            allCustomIcons: vault.files.current.body.meta.customIcons.map((key, value) => MapEntry(
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
        } else {
          return Scaffold(
            key: widget.key,
            appBar: AppBar(),
            body: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const <Widget>[
                    LoadingSpinner(tooltip: 'Please wait...'),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }
}
