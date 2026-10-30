import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/logging/logger.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../autofill_matching.dart';
import '../autofill_save_draft.dart';
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
    _ownPackageName ??= (await PackageInfo.fromPlatform()).packageName;

    bool autofillRequested = await AutofillService().fillRequestedAutomatic;
    bool autofillForceInteractive = await AutofillService().fillRequestedInteractive;
    final androidMetadata = await AutofillService().autofillMetadata;
    bool saveRequested = androidMetadata?.saveInfo != null;

    if (!autofillRequested && !autofillForceInteractive && !saveRequested) {
      emit(AutofillAvailable(enabled));
      return;
    }
    if (saveRequested) {
      _trackTarget('saveRequest', assessTarget(androidMetadata!));
      emit(AutofillSaving(androidMetadata, requestId: ++_saveRequestCounter));
      return;
    }

    if (androidMetadata == null) {
      throw Exception('Android failed to provide the necessary autofill information.');
    }

    // we only call this cubit's function if we have some sort of intent relating to the
    // autofill service so we can now assume the user is asking for us to autofill another app/site
    l.d('Autofill requested. automatic: $autofillRequested, interactive: $autofillForceInteractive');
    final target = assessTarget(androidMetadata);
    _trackTarget('request', target);
    emit(AutofillRequested(target, androidMetadata));

    // A later request can arrive while the vault is already open, in which case nothing else will trigger matching.
    final vault = _vaultForMatching;
    if (vault != null) prepareMatches(vault);
  }

  /// Read once, before any autofill state is emitted
  String? _ownPackageName;

  @visibleForTesting
  set ownPackageNameForTesting(String value) => _ownPackageName = value;

  int _saveRequestCounter = 0;

  /// What a fill or save request is for, and how far we can trust it
  AutofillTarget assessTarget(AutofillMetadata metadata) =>
      AutofillTarget.fromMetadata(metadata, ownPackageName: _ownPackageName!);

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
    _track('select', name: s.matches?[entry.uuid.uuid]?.tier.name ?? 'unmatched');
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
    final s = state;
    if (s is AutofillRequested && !s.target.excluded) _track('cancel');
    final ok = await AutofillService().resultWithDatasets(null);
    l.d('resultWithDatasets(null) $ok');
  }

  /// The user saved the new entry. Autofill mode ends so the app behaves normally if the user returns to it.
  Future<void> finishSaving() async {
    l.t('Autofillcubit.finishSaving');
    await _endSaving('saved');
  }

  /// The user chose not to save, or left the save screen in some other way that discards the new entry. Nothing has been
  /// added to the vault by then so there is nothing to undo here.
  Future<void> abandonSaving() async {
    l.t('Autofillcubit.abandonSaving');
    await _endSaving('discarded');
  }

  Future<void> _endSaving(String outcome) async {
    final s = state;
    if (s is! AutofillSaving) return;
    _trackSaveOutcome(outcome, s);
    emit(AutofillAvailable(true));
    await AutofillService().onSaveComplete();
  }

  /// Only the outcome and whether the request was trusted are sent, never an app id, domain or credential.
  void _trackSaveOutcome(String outcome, AutofillSaving s) {
    try {
      final trusted = AutofillSaveDraft.isTrusted(assessTarget(s.androidMetadata));
      _track('saveOutcome', name: outcome, value: trusted ? 1 : 0);
    } catch (e) {
      l.w('Failed to track autofill save outcome', error: e);
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

  /// Records the user's answer when we asked before filling. [kind] says why we asked.
  void trackConfirmation(String kind, bool accepted) => _track('confirm', name: kind, value: accepted ? 1 : 0);

  /// How trustworthy autofill requests are in practice. Only enum names and counts are sent, never an app id or domain.
  void _trackTarget(String action, AutofillTarget target) {
    if (target.excluded) {
      _track(action, name: 'excluded');
      return;
    }
    final app = target.app;
    final web = target.web;
    final appState = app != null
        ? app.source.name
        : target.inTrustedBrowser
        ? 'browser'
        : target.contextAppId != null
        ? 'claimedBrowser'
        : 'none';
    final webState = web == null
        ? 'none'
        : web.trust == SignalTrust.verified
        ? 'verified'
        : web.domain.userSelected
        ? 'userSelected'
        : 'unverified';
    final others = target.otherDomains.length;
    _track(action, name: 'app=$appState web=$webState others=${others > 3 ? '3+' : others}');
    for (final concern in target.concerns) {
      _track('${action}Concern', name: concern.name);
    }
  }

  void _track(String action, {String? name, num? value}) {
    try {
      MatomoTracker.instance.trackEvent(
        eventInfo: EventInfo(category: 'autofill', action: action, name: name, value: value),
      );
    } catch (e) {
      l.w('Failed to track autofill event $action', error: e);
    }
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
