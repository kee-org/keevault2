import 'dart:io' show InternetAddress;

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

enum AutofillDecision { ignore, refer, proceed }

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
    final trust = determineTrustLevel(androidMetadata);
    if (trust == AutofillDecision.ignore) {
      l.d('ignoring autofillWithList request');
      await AutofillService().resultWithDatasets(null);
      return false;
    } else if (trust == AutofillDecision.refer) {
      l.d('deferring autofill decision to the user');
      return true;
    }

    final matchingEntries = AutofillCubit.findMatchingEntries(
      androidMetadata,
      vault.files.current.body.rootGroup.getAllEntries(enterRecycleBin: false).values,
      vault.files.current,
    );
    if (matchingEntries.isNotEmpty) {
      // Limited to 10 results due to Android Parcelable bugs. Totally arbitrary but we have to start somewhere.
      // Autofill library may further reduce the number if the device IME requests fewer than 11 results
      final datasets = matchingEntries.take(10).map(entryToPwDataset).toList();
      final response = await AutofillService().resultWithDatasets(datasets);
      l.d('resultWithDatasets $response');
      return false; // kinda pointless since Android will kill us shortly but meh
    } else {
      return true;
    }
  }

  AutofillDecision determineTrustLevel(AutofillMetadata androidMetadata) {
    if (androidMetadata.appId?.isNotEmpty ?? false) {
      if (_excludedPackages.contains(androidMetadata.appId)) {
        l.i('Supplied packageName is on our exclude list. We will ignore this autofill request.');
        return AutofillDecision.ignore;
      }
      if (!androidMetadata.appIdTrusted) {
        l.w('Untrusted package name found for autofill (${androidMetadata.appId}).');
        return AutofillDecision.refer;
      }
      return AutofillDecision.proceed;
    }

    if (androidMetadata.isWebOrigin) {
      if (androidMetadata.webDomains.length > 1) {
        l.e(
          "Multiple domains found for autofill (${androidMetadata.webDomains.map((d) => d.domain).join(', ')}). We will ignore this autofill request because we don't know why this can happen or whether we can trust the claimed domains.",
        );
        return AutofillDecision.ignore;
      }
      if (!androidMetadata.dalVerified) {
        l.w('Supplied domain could not be verified as trusted by any method. We will ignore this autofill request.');
        return AutofillDecision.refer;
      }

      return AutofillDecision.proceed;
    }
    l.w('Supplied domain is empty and no packageName was found. We will ignore this autofill request.');
    return AutofillDecision.ignore;
  }

  bool isAppIdTrusted(AutofillMetadata androidMetadata) {
    final appId = androidMetadata.appId;
    if (appId == null || appId.isEmpty) return false;
    if (_excludedPackages.contains(appId)) return false;
    return androidMetadata.appIdTrusted;
  }

  bool isWebDomainTrusted(AutofillMetadata androidMetadata) {
    if (!androidMetadata.isWebOrigin) return false;
    if (androidMetadata.webDomains.length > 1) return false;
    return androidMetadata.dalVerified;
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
    var compareHostname = minimumMatchAccuracy != MatchAccuracy.Domain;
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
      final host = testUrl.publicSuffixUrl.sourceUrl.host;
      if (minimumMatchAccuracy == MatchAccuracy.Domain && !_isIpAddress(host)) {
        testValue = testUrl.publicSuffixUrl.domain ?? host;
      } else {
        // IP addresses have no registrable domain (the public suffix list would treat 1.2.3.4 as domain "3.4")
        // so they must always be compared in full.
        compareHostname = true;
        testValue = host;
      }
    } else {
      testValue = pattern;
    }

    final requestValue = compareHostname ? hostname : registrableDomain;
    if (testValue is String) {
      // Must be equality, not String.allMatches which finds substrings (e.g. bank.com within evilbank.com)
      return testValue.toLowerCase() == requestValue.toLowerCase();
    }
    return testValue.allMatches(requestValue).firstOrNull != null;
  }

  static bool _isIpAddress(String host) {
    final unbracketed = host.startsWith('[') && host.endsWith(']') ? host.substring(1, host.length - 1) : host;
    return InternetAddress.tryParse(unbracketed) != null;
  }

  bool isAutofilling() => state is AutofillRequested;
  bool isAutofillSaving() => state is AutofillSaving;

  // Shared matching logic used by both automatic autofill and manual entry list selection
  static List<KdbxEntry> findMatchingEntries(
    AutofillMetadata metadata,
    Iterable<KdbxEntry> entries,
    KdbxFile? vaultFile,
  ) {
    //TODO: Why not search for both at the same time? regression?! no. existing bug.
    if (metadata.appId != null && metadata.appId!.isNotEmpty) {
      return _findMatchesByPackageName(metadata, entries);
    } else if (metadata.webDomains.isNotEmpty) {
      return _findMatchesByDomain(metadata, entries, vaultFile);
    }
    return [];
  }

  static List<KdbxEntry> _findMatchesByPackageName(AutofillMetadata metadata, Iterable<KdbxEntry> entries) {
    final appId = metadata.appId!;
    return entries.where((entry) {
      if (entry.browserSettings.matcherConfigs.any((mc) => mc.matcherType == EntryMatcherType.Hide)) {
        return false;
      }
      return entry.androidPackageNames.contains(appId);
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
        if (urlsMatch(pattern, minimumMatchAccuracy, scheme, hostname, registrableDomain)) {
          isAMatch = true;
          break;
        }
      }

      if (isAMatch) {
        for (final p in entry.browserSettings.excludeUrls) {
          if (p is String) {
            if (urlsMatch(p, minimumMatchAccuracy, scheme, hostname, registrableDomain)) {
              isAMatch = false;
              break;
            }
          }
        }
      }

      return isAMatch;
    }).toList();
  }

  // top-level entrylist should only be displayed if above is false, otherwise display the editing page for the new entry we are going to save
}
