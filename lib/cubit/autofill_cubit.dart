import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/logging/logger.dart';

import '../autofill_matching.dart';
import '../config/platform.dart';
import '../vault_file.dart';
import 'vault_cubit.dart';

part 'autofill_state.dart';

class AutofillCubit extends Cubit<AutofillState> {
  AutofillCubit() : super(AutofillInitial());

  static const _autoFillMethodChannel = MethodChannel('com.keevault.keevault/autofill');

  Future<void> refresh() async {
    if (KeeVaultPlatform.isIOS) {
      final iosAutofillStatus = await _autoFillMethodChannel.invokeMethod('getAutofillStatus');
      final iosAvailable = iosAutofillStatus > 0;
      final iosEnabled = iosAutofillStatus == 2;
      if (!iosAvailable) {
        emit(AutofillMissing());
        return;
      } else {
        emit(AutofillAvailable(iosEnabled));
        return;
      }
    }
    final available = await AutofillService().hasAutofillServicesSupport;
    final enabled = available ? await AutofillService().status == AutofillServiceStatus.enabled : false;
    if (!available) {
      emit(AutofillMissing());
      return;
    }

    await ensureInAppSelectionPreferences();

    bool autofillRequested = await AutofillService().fillRequestedAutomatic;
    bool autofillForceInteractive = await AutofillService().fillRequestedInteractive;
    final androidMetadata = await AutofillService().autofillMetadata;
    bool saveRequested = androidMetadata?.saveInfo != null;

    if (!autofillRequested && !autofillForceInteractive && !saveRequested) {
      emit(AutofillAvailable(enabled));
      return;
    }
    //TODO:f: should below be here? or after potential emit of autofill request for filling?
    // if (state is AutofillSaved) {
    //   emit(AutofillAvailable(enabled));
    //   return;
    // }
    if (saveRequested) {
      emit(AutofillSaving(androidMetadata!));
      return;
    }

    if (androidMetadata == null) {
      throw Exception('Android failed to provide the necessary autofill information.');
    }

    // we only call this cubit's function if we have some sort of intent relating to the
    // autofill service so we can now assume the user is asking for us to autofill another app/site
    l.d('Autofill requested. automatic: $autofillRequested, interactive: $autofillForceInteractive');
    emit(AutofillRequested(AutofillTarget.fromMetadata(androidMetadata), androidMetadata));

    // A later request can arrive while the vault is already open, in which case nothing else will trigger matching.
    final vault = _vaultForMatching;
    if (vault != null) prepareMatches(vault);
  }

  LocalVaultFile? _vaultForMatching;

  /// Works out which entries match the current request. The vault cannot change while autofilling (refresh is skipped
  /// and entries cannot be created) so the result stays valid for the whole request.
  void prepareMatches(LocalVaultFile vault) {
    final s = state;
    if (s is! AutofillRequested) return;
    _vaultForMatching = vault;
    final file = vault.files.current;
    final matches = AutofillMatches.compute(
      s.target,
      file.body.rootGroup.getAllEntries(enterRecycleBin: false).values,
      file,
    );
    emit(s.copyWith(matches: matches));
  }

  void setLinkUnverifiedDomain(bool value) {
    final s = state;
    if (s is AutofillRequested) emit(s.copyWith(linkUnverifiedDomain: value));
  }

  /// One path for every selection, whether the entry matched or came from elsewhere in the vault.
  Future<void> fillWithEntry(KdbxEntry entry, VaultCubit vaultCubit, {required bool linkUnverifiedDomain}) async {
    final s = state;
    if (s is! AutofillRequested) return;
    final association = s.target.associationFor(
      entry.uuid.uuid,
      s.matches?[entry.uuid.uuid],
      linkUnverifiedDomain: linkUnverifiedDomain,
    );
    if (association != null) await vaultCubit.addAutofillPersistentQueueItem(association);
    final ds = entryToPwDataset(entry);
    final ok = await AutofillService().resultWithDataset(
      id: ds.id,
      label: ds.label,
      username: ds.username,
      password: ds.password,
    );
    l.d('resultWithDataset $ok');
  }

  /// Declines the request without filling anything. Android still offers the locked suggestion afterwards.
  Future<void> cancelFill() async {
    final ok = await AutofillService().resultWithDatasets(null);
    l.d('resultWithDatasets(null) $ok');
  }

  Future<void> finishSaving() async {
    l.t('Autofillcubit.finishSaving');
    if (state is AutofillSaving || state is AutofillSaved) {
      emit(AutofillSaved((state as AutofillModeActive).androidMetadata));
      await AutofillService().onSaveComplete();
    }
  }

  Future<void> requestEnable() async {
    l.d('Starting autofill enable request.');
    final response = await AutofillService().requestSetAutofillService();
    l.d('autofill enable request finished $response');
    final available = await AutofillService().hasAutofillServicesSupport;
    final enabled = available ? await AutofillService().status == AutofillServiceStatus.enabled : false;
    if (!available) {
      emit(AutofillMissing());
    }
    emit(AutofillAvailable(enabled));
  }

  Future<void> setSavingPreference(bool value) async {
    final prefs = await AutofillService().preferences;
    await AutofillService().setPreferences(prefs.copyWith(enableSaving: value));
  }

  Future<void> setDebugEnabledPreference(bool value) async {
    if (KeeVaultPlatform.isIOS) {
      final iosAutofillEnableDebug =
          await _autoFillMethodChannel.invokeMethod<bool>('setDebugEnabled', <String, dynamic>{
            'debugEnabled': value,
          }) ??
          false;
      if (!iosAutofillEnableDebug) {
        l.e('Failed to set debug status for autofill service');
      }
    } else {
      final prefs = await AutofillService().preferences;
      await AutofillService().setPreferences(prefs.copyWith(enableDebug: value));
    }
  }

  Future<void> setIMEIntegrationPreference(bool value) async {
    final prefs = await AutofillService().preferences;
    await AutofillService().setPreferences(prefs.copyWith(enableIMERequests: value));
  }

  Future<void> setFillDialogPreference(bool value) async {
    final prefs = await AutofillService().preferences;
    await AutofillService().setPreferences(prefs.copyWith(enableFillDialog: value));
  }

  bool _inAppSelectionPreferencesEnsured = false;

  /// Kee Vault always uses the plugin's select-in-app flow (one locked suggestion that opens our own entry picker).
  /// The service reads preferences on every fill request so this takes effect from the first request after the
  /// app has run once following an upgrade. Requests made before then use the legacy flow, which we also handle.
  Future<void> ensureInAppSelectionPreferences() async {
    if (_inAppSelectionPreferencesEnsured) return;
    final prefs = await AutofillService().preferences;
    if (!prefs.useInAppSelection || !prefs.useEphemeralDataset) {
      await AutofillService().setPreferences(prefs.copyWith(useInAppSelection: true, useEphemeralDataset: true));
    }
    _inAppSelectionPreferencesEnsured = true;
  }

  PwDataset entryToPwDataset(KdbxEntry entry) {
    final id = entry.uuid.uuid;
    final title = entry.getString(KdbxKeyCommon.TITLE)?.getText() ?? 'untitled entry';
    final username = entry.getString(KdbxKeyCommon.USER_NAME)?.getText() ?? '';
    final pwd = entry.getString(KdbxKeyCommon.PASSWORD)?.getText() ?? '';
    return PwDataset(id: id, label: title, username: username, password: pwd);
  }

  bool isAutofilling() => state is AutofillRequested;
  bool isAutofillSaving() => state is AutofillSaving;
}
