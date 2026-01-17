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

    final matchingEntries = _findMatches(androidMetadata, vault.files.current);
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
    if (androidMetadata.packageNames.length > 1) {
      l.e(
        "Multiple package names found for autofill. We will ignore this autofill request because we don't know why this can happen or whether we can trust the claimed names.",
      );
      ignoreRequest = true;
    }
    if (androidMetadata.webDomains.length > 1) {
      l.e(
        "Multiple domains found for autofill. We will ignore this autofill request because we don't know why this can happen or whether we can trust the claimed domains.",
      );
      ignoreRequest = true;
    }
    if ((androidMetadata.webDomains.firstOrNull?.domain.isEmpty ?? true) &&
        (androidMetadata.packageNames.firstOrNull?.isEmpty ?? true)) {
      l.w('Supplied domain is empty and no packageName was found. We will ignore this autofill request.');
      ignoreRequest = true;
    }
    if (androidMetadata.packageNames.firstOrNull != null &&
        _excludedPackages.contains(androidMetadata.packageNames.firstOrNull)) {
      l.i('Supplied packageName is on our exclude list. We will ignore this autofill request.');
      ignoreRequest = true;
    }
    return ignoreRequest;
  }

  PwDataset entryToPwDataset(KdbxEntry entry) {
    final title = entry.getString(KdbxKeyCommon.TITLE)?.getText() ?? 'untitled entry';
    final username = entry.getString(KdbxKeyCommon.USER_NAME)?.getText() ?? '';
    final pwd = entry.getString(KdbxKeyCommon.PASSWORD)?.getText() ?? '';
    return PwDataset(label: title, username: username, password: pwd);
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

  List<KdbxEntry> _findMatches(AutofillMetadata androidMetadata, KdbxFile current) {
    if (androidMetadata.webDomains.isEmpty) {
      return _findMatchesByPackageName(androidMetadata, current);
    } else {
      return _findMatchesByDomain(androidMetadata, current);
    }
  }

  List<KdbxEntry> _findMatchesByPackageName(AutofillMetadata androidMetadata, KdbxFile current) {
    final matches = <KdbxEntry>[];
    matches.addAll(
      current.body.rootGroup
          .getAllEntries(enterRecycleBin: false)
          .values
          .where(
            (entry) =>
                !entry.browserSettings.matcherConfigs.any((mc) => mc.matcherType == EntryMatcherType.Hide) &&
                entry.androidPackageNames.any((pn) => androidMetadata.packageNames.contains(pn)),
          ),
    );
    return matches;
  }

  List<KdbxEntry> _findMatchesByDomain(AutofillMetadata androidMetadata, KdbxFile current) {
    // Android only provides us with the host and scheme (in 9+) so compared to Kee,
    // we can't apply the same level of control over which entries we consider a match.
    // Old versions of Android don't tell us the scheme so we have to assume it is
    // https otherwise we'll rarely be able to match any entries.
    final requestedUrl = urls.parse(
      "${androidMetadata.webDomains.firstOrNull?.scheme ?? 'https'}://${androidMetadata.webDomains.firstOrNull?.domain ?? ''}"
          .trim(),
    );

    // Apparently Android never supplies us with a port so this is the best we can do
    final hostname = requestedUrl?.publicSuffixUrl.sourceUrl.host;

    final registrableDomain = requestedUrl?.publicSuffixUrl.domain;
    final scheme = requestedUrl?.publicSuffixUrl.sourceUrl.scheme;

    final matches = <KdbxEntry>[];

    if (hostname == null || registrableDomain == null || scheme == null) {
      l.e(
        "Android supplied a WebDomain we can't understand. Please report the exact web page you encounter this error on so we can see if it is possible to add support for autofilling this in future.",
      );
      return matches;
    }
    final matchAccuracyDomainOverride = MatchAccuracy.values.singleWhereOrNull(
      (val) => val.name == current.body.meta.browserSettings.matchedURLAccuracyOverrides[registrableDomain],
    );

    matches.addAll(
      current.body.rootGroup.getAllEntries(enterRecycleBin: false).values.where((entry) {
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

        final matchPatterns = entry.browserSettings.includeUrls.toList();
        final primaryUrlString = entry.getString(KdbxKeyCommon.URL)?.getText();

        if (primaryUrlString != null) {
          matchPatterns.add(primaryUrlString);
        }
        for (var pattern in matchPatterns) {
          if (urlsMatch(pattern, minimumMatchAccuracy, scheme, hostname, registrableDomain)) {
            isAMatch = true;
            break;
          }
        }

        if (isAMatch) {
          for (var pattern in entry.browserSettings.excludeUrls) {
            if (urlsMatch(pattern, minimumMatchAccuracy, scheme, hostname, registrableDomain)) {
              isAMatch = false;
              break;
            }
          }
        }

        return isAMatch;
      }),
    );
    return matches;
  }

  @visibleForTesting
  bool urlsMatch(
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

  // top-level entrylist should only be displayed if above is false, otherwise display the editing page for the new entry we are going to save
}
