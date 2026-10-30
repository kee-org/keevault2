import 'package:collection/collection.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/autofill_matching.dart';
import 'package:keevault/autofill_save_draft.dart';
import 'package:keevault/cubit/account_cubit.dart';
import 'package:keevault/cubit/autocomplete_cubit.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/cubit/filter_cubit.dart';
import 'package:keevault/cubit/vault_cubit.dart';
import 'package:keevault/extension_methods.dart';
import 'package:keevault/generated/l10n.dart';
import 'package:keevault/widgets/autofill_target_card.dart';
import 'package:keevault/widgets/loading_spinner.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import '../logging/logger.dart';
import 'coloured_safe_area_widget.dart';
import 'entry.dart';

/// Shows the entry that we could create from an Android save request. Nothing is added to the vault until the user
/// taps Save. Every other way of leaving the screen asks first and discards the entry unless the user chooses Save.
/// The screen is built afresh for every request (see the key in VaultWidget) so it never shows another request's data.
class AutofillSaveWidget extends StatefulWidget {
  const AutofillSaveWidget({super.key});

  @override
  State<AutofillSaveWidget> createState() => _AutofillSaveWidgetState();
}

class _AutofillSaveWidgetState extends State<AutofillSaveWidget> with TraceableClientMixin {
  @override
  String get actionName => widget.toStringShort();

  AutofillTarget? _target;
  AutofillSaveDraft? _draft;
  bool _finishing = false;

  @override
  void initState() {
    l.t('_AutofillSaveWidgetState.initState');
    super.initState();
    final autofillCubit = BlocProvider.of<AutofillCubit>(context);
    final autofillState = autofillCubit.state;
    final vault = BlocProvider.of<VaultCubit>(context).currentVaultFile;
    if (autofillState is! AutofillSaving || vault == null) {
      return;
    }
    //TODO:f: expose value of save compat mode to Entry widget:
    //final isCompatMode = autofillState.androidMetadata.saveInfo!.isCompatMode;

    final target = autofillCubit.assessTarget(autofillState.androidMetadata);
    _target = target;
    _draft = AutofillSaveDraft.from(autofillState.androidMetadata, target);
    BlocProvider.of<EntryCubit>(context).startCreatingFromAutofill(vault.files.current, _draft!);
  }

  Future<void> onEndEditing(bool keepChanges) async {
    // Both buttons and the back gestures can be used repeatedly while we wait for the save to finish
    if (_finishing) return;
    _finishing = true;

    final entryCubit = BlocProvider.of<EntryCubit>(context);
    final autofillCubit = BlocProvider.of<AutofillCubit>(context);
    if (!keepChanges) {
      // Nothing has been added to the vault, queued or saved so there is nothing to undo.
      entryCubit.endCreating(null);
      await autofillCubit.abandonSaving();
      return;
    }

    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    final accountCubit = BlocProvider.of<AccountCubit>(context);
    final filterCubit = BlocProvider.of<FilterCubit>(context);
    final autocompleteCubit = BlocProvider.of<AutocompleteCubit>(context);
    final file = vaultCubit.currentVaultFile?.files.current;
    if (file == null) {
      throw Exception('Vault file missing');
    }

    final username =
        (entryCubit.state as EntryLoaded).entry.fields
            .firstWhereOrNull((f) => f.key == KdbxKeyCommon.USER_NAME)
            ?.textValue
            .trim() ??
        '';
    entryCubit.endCreating(file);
    autocompleteCubit.addUsername(username);

    // We skip remote upload for now because it could take a long time
    // and interrupt the user's priority task for too long.
    await vaultCubit.save(accountCubit.currentUserIfKnown, skipRemote: true);

    // User may return to this Kee Vault instance in future and will
    // want the filter options to reflect any changes made while
    // adding this new entry
    final savedFile = vaultCubit.currentVaultFile!.files.current;
    filterCubit.reFilter(savedFile.trimmedTags, savedFile.body.rootGroup);

    await autofillCubit.finishSaving();
  }

  /// Says what will happen to the entry and, if we couldn't verify who asked for it, why it has not been linked.
  Widget _buildHeader(BuildContext context) {
    final draft = _draft;
    final target = _target;
    if (draft == null || target == null) return const SizedBox.shrink();
    final str = S.of(context);
    final theme = Theme.of(context);
    final text = draft.trusted
        ? str.autofillSaveHeaderTrusted
        : draft.hasLinks
        ? str.autofillSaveHeaderPartlyTrusted
        : str.autofillSaveHeaderUntrusted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: theme.textTheme.bodyLarge),
        if (!draft.trusted) ...[const SizedBox(height: 12), AutofillConcernBanners(target: target, saving: true)],
        if (draft.sameValue) ...[
          const SizedBox(height: 12),
          _SameValueNotice(message: str.autofillSaveSameValueNotice),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntryCubit, EntryState>(
      builder: (context, state) {
        if (state is EntryLoaded) {
          final vault = BlocProvider.of<VaultCubit>(context).currentVaultFile;
          if (vault == null) {
            throw Exception('Vault file missing');
          }
          return EntryWidget(
            key: ValueKey('autofillSaveDetails'),
            savingViaAutofill: true,
            autofillSaveHeader: _buildHeader(context),
            endEditing: onEndEditing,
            allCustomIcons: vault.files.current.body.meta.customIcons.map(
              (key, value) =>
                  MapEntry(value, Image.memory(value.data, fit: BoxFit.contain, filterQuality: FilterQuality.low)),
            ),
            revertTo: (int index) {},
            deleteAt: (int index) {},
          );
        } else {
          return ColouredSafeArea(
            child: Scaffold(
              key: widget.key,
              appBar: AppBar(),
              body: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const <Widget>[LoadingSpinner(tooltip: 'Please wait...')],
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

/// Same look as a caution banner for a trust concern
class _SameValueNotice extends StatelessWidget {
  final String message;

  const _SameValueNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onTertiaryContainer;
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: theme.colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: foreground, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}
