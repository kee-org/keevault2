import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/logging/logger.dart';
import 'package:collection/collection.dart';

import '../config/platform.dart';
import '../urls.dart';
import '../vault_file.dart';

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
    emit(AutofillRequested(autofillForceInteractive, androidMetadata));
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
    await AutofillService().setPreferences(
      AutofillPreferences(
        enableDebug: prefs.enableDebug,
        enableSaving: value,
        enableIMERequests: prefs.enableIMERequests,
      ),
    );
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
      await AutofillService().setPreferences(
        AutofillPreferences(
          enableDebug: value,
          enableSaving: prefs.enableSaving,
          enableIMERequests: prefs.enableIMERequests,
        ),
      );
    }
  }

  Future<void> setIMEIntegrationPreference(bool value) async {
    final prefs = await AutofillService().preferences;
    await AutofillService().setPreferences(
      AutofillPreferences(enableDebug: prefs.enableDebug, enableSaving: prefs.enableSaving, enableIMERequests: value),
    );
  }

  Future<bool> autofillWithList(LocalVaultFile vault) async {
    final androidMetadata = (state as AutofillRequested).androidMetadata;
    if (shouldIgnoreRequest(androidMetadata)) {
      l.d('ignoring autofillWithList request');
      await AutofillService().resultWithDatasets(null);
      return true;
    }

    final matchingEntries = AutofillCubit.findMatchingEntries(androidMetadata, vault.files.current.body.rootGroup.getAllEntries(enterRecycleBin: false).values, vault.files.current);
    if (matchingEntries.isNotEmpty) {
      // Limited to 10 results due to Android Parcelable bugs. Totally arbitrary but we have to start somewhere.
      // Autofill library may further reduce the number if the device IME requests fewer than 11 results
      final datasets = matchingEntries.take(10).map(entryToPwDataset).toList();
      final response = await AutofillService().resultWithDatasets(datasets);
      l.d('resultWithDatasets $response');
      return true; // kinda pointless since Android will kill us shortly but meh
    } else {
      return false;
    }
  }

  bool shouldIgnoreRequest(AutofillMetadata androidMetadata) {
    bool ignoreRequest = false;
    if ((androidMetadata.appId?.isNotEmpty ?? false) && !androidMetadata.appIdTrusted) {
      l.w('Untrusted package name found for autofill (${androidMetadata.appId}).');
      ignoreRequest = true;
    }
    if (androidMetadata.webDomains.length > 1) {
      l.e(
        "Multiple domains found for autofill (${androidMetadata.webDomains.map((d) => d.domain).join(', ')}). We will ignore this autofill request because we don't know why this can happen or whether we can trust the claimed domains.",
      );
      ignoreRequest = true;
    }
    if (androidMetadata.isWebOrigin && !androidMetadata.dalVerified) {
      l.w('Supplied domain could not be verified as trusted by any method. We will ignore this autofill request.');
      ignoreRequest = true;
    }
    if ((androidMetadata.webDomains.firstOrNull?.domain.isEmpty ?? true) && (androidMetadata.appId?.isEmpty ?? true)) {
      l.w('Supplied domain is empty and no packageName was found. We will ignore this autofill request.');
      ignoreRequest = true;
    }
    if (androidMetadata.appId != null && _excludedPackages.contains(androidMetadata.appId)) {
      l.i('Supplied packageName is on our exclude list. We will ignore this autofill request.');
      ignoreRequest = true;
    }
    return ignoreRequest;
  }

  PwDataset entryToPwDataset(KdbxEntry entry) {
    final id = entry.uuid.uuid;
    final title = entry.getString(KdbxKeyCommon.TITLE)?.getText() ?? 'untitled entry';
    final username = entry.getString(KdbxKeyCommon.USER_NAME)?.getText() ?? '';
    final pwd = entry.getString(KdbxKeyCommon.PASSWORD)?.getText() ?? '';
    return PwDataset(id: id, label: title, username: username, password: pwd);
  }

  void autofillInstantly(KdbxEntry entry) async {
    final dataset = entryToPwDataset(entry);
    final response = await AutofillService().resultWithDataset(
      label: dataset.label,
      username: dataset.username,
      password: dataset.password,
    );
    l.d('resultWithDataset $response');
  }

  void autofillWithListOfOneEntry(KdbxEntry entry) async {
    final dataset = entryToPwDataset(entry);
    final response = await AutofillService().resultWithDatasets([dataset]);
    l.d('resultWithDatasets $response');
  }

  static final Set<String> _excludedPackages = <String>{
    'com.keevault.keevault',
    'android',
    'com.android.settings',
    'com.oneplus.applocker',
  };

  @visibleForTesting
  static bool urlsMatch(
    Pattern pattern,
    MatchAccuracy minimumMatchAccuracy,
    String scheme,
    String hostname,
    String registrableDomain,
  ) {
    Pattern testValue;
    if (pattern is String) {
      final testUrl = urls.parse(pattern.trim());
      if (testUrl == null) {
        // If the user has not supplied a valid URL, we cannot safely permit it to match anything
        return false;
      }
      if (scheme == 'http' && testUrl.publicSuffixUrl.sourceUrl.scheme == 'https') {
        // Prevent matching secure URLs in entries with an insecure version of the website but not vice-versa
        return false;
      }

      // If user has requested Exact, we use Hostname matching instead since it is stricter than Domain, but unfortunately
      // we don't have the required information from Android to be able to perform the exact match the user requested.
      if (minimumMatchAccuracy == MatchAccuracy.Domain) {
        testValue = testUrl.publicSuffixUrl.domain ?? testUrl.publicSuffixUrl.sourceUrl.host;
      } else {
        testValue = testUrl.publicSuffixUrl.sourceUrl.host;
      }
    } else {
      testValue = pattern;
    }

    if (minimumMatchAccuracy == MatchAccuracy.Domain) {
      if (testValue.allMatches(registrableDomain).firstOrNull != null) {
        return true;
      }
    } else {
      if (testValue.allMatches(hostname).firstOrNull != null) {
        return true;
      }
    }
    return false;
  }

  bool isAutofilling() => state is AutofillRequested;
  bool isAutofillSaving() => state is AutofillSaving;

  // Shared matching logic used by both automatic autofill and manual entry list selection
  static List<KdbxEntry> findMatchingEntries(
    AutofillMetadata metadata,
    Iterable<KdbxEntry> entries,
    KdbxFile? vaultFile,
  ) {
    if (metadata.webDomains.isNotEmpty) {
      return _findMatchesByDomain(metadata, entries, vaultFile);
    } else if (metadata.appId != null && metadata.appId!.isNotEmpty) {
      return _findMatchesByPackageName(metadata, entries);
    }
    return [];
  }

  static List<KdbxEntry> _findMatchesByPackageName(
    AutofillMetadata metadata,
    Iterable<KdbxEntry> entries,
  ) {
    final appId = metadata.appId!;
    return entries.where((entry) {
      if (entry.browserSettings.matcherConfigs.any((mc) => mc.matcherType == EntryMatcherType.Hide)) {
        return false;
      }
      return entry.androidPackageNames.any((pn) => appId.contains(pn));
    }).toList();
  }

  static List<KdbxEntry> _findMatchesByDomain(
    AutofillMetadata metadata,
    Iterable<KdbxEntry> entries,
    KdbxFile? vaultFile,
  ) {
    final requestedUrl = urls.parse(
      "${metadata.webDomains.firstOrNull?.scheme ?? 'https'}://${metadata.webDomains.firstOrNull?.domain ?? ''}".trim(),
    );

    if (requestedUrl == null) return [];

    final hostname = requestedUrl.publicSuffixUrl.sourceUrl.host;
    final registrableDomain = requestedUrl.publicSuffixUrl.domain;
    final scheme = requestedUrl.publicSuffixUrl.sourceUrl.scheme;

    if (hostname == null || registrableDomain == null || scheme == null) {
      return [];
    }

    // Check for domain-specific match accuracy override from vault metadata
    final matchAccuracyDomainOverride = vaultFile != null
        ? MatchAccuracy.values.singleWhereOrNull(
            (val) => val.name == vaultFile.body.meta.browserSettings.matchedURLAccuracyOverrides[registrableDomain],
          )
        : null;

    return entries.where((entry) {
      if (entry.browserSettings.matcherConfigs.any((mc) => mc.matcherType == EntryMatcherType.Hide)) {
        return false;
      }
      bool isAMatch = false;
      var minimumMatchAccuracy =
          matchAccuracyDomainOverride ??
          entry.browserSettings.matcherConfigs
              .firstWhereOrNull((mc) => mc.matcherType == EntryMatcherType.Url)
              ?.urlMatchMethod ??
          MatchAccuracy.Domain;

      final matchPatterns = <String>[];
      for (final p in entry.browserSettings.includeUrls) {
        if (p is String) matchPatterns.add(p);
      }
      final primaryUrlString = entry.getString(KdbxKeyCommon.URL)?.getText();

      if (primaryUrlString != null) {
        matchPatterns.add(primaryUrlString);
      }
      for (final String pattern in matchPatterns) {
        if (_urlsMatch(pattern, minimumMatchAccuracy, scheme, hostname, registrableDomain)) {
          isAMatch = true;
          break;
        }
      }

      if (isAMatch) {
        for (final p in entry.browserSettings.excludeUrls) {
          if (p is String) {
            if (_urlsMatch(p, minimumMatchAccuracy, scheme, hostname, registrableDomain)) {
              isAMatch = false;
              break;
            }
          }
        }
      }

      return isAMatch;
    }).toList();
  }

  static bool _urlsMatch(
    String pattern,
    MatchAccuracy minimumMatchAccuracy,
    String scheme,
    String hostname,
    String registrableDomain,
  ) {
    final testUrl = urls.parse(pattern.trim());
    if (testUrl == null) {
      // If the user has not supplied a valid URL, we cannot safely permit it to match anything
      return false;
    }
    if (scheme == 'http' && testUrl.publicSuffixUrl.sourceUrl.scheme == 'https') {
      // Prevent matching secure URLs in entries with an insecure version of the website but not vice-versa
      return false;
    }

    // If user has requested Exact, we use Hostname matching instead since it is stricter than Domain, but unfortunately
    // we don't have the required information from Android to be able to perform the exact match the user requested.
    Pattern testValue;
    if (minimumMatchAccuracy == MatchAccuracy.Domain) {
      testValue = testUrl.publicSuffixUrl.domain ?? testUrl.publicSuffixUrl.sourceUrl.host;
    } else {
      testValue = testUrl.publicSuffixUrl.sourceUrl.host;
    }

    if (minimumMatchAccuracy == MatchAccuracy.Domain) {
      return testValue.allMatches(registrableDomain).firstOrNull != null;
    } else {
      return testValue.allMatches(hostname).firstOrNull != null;
    }
  }

  // top-level entrylist should only be displayed if above is false, otherwise display the editing page for the new entry we are going to save
}
