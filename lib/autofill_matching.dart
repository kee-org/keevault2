import 'dart:io' show InternetAddress;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:kdbx/kdbx.dart';

import 'urls.dart';

/// How much we can rely on the identity of the app or website that Android says is asking for credentials.
enum SignalTrust { verified, unverified }

class AppSignal {
  final String appId;
  final SignalTrust trust;

  /// Where Android's autofill metadata got [appId] from. Only [AppIdSource.component] is verified.
  final AppIdSource source;
  const AppSignal(this.appId, this.trust, this.source);
}

class WebSignal {
  final AutofillWebDomain domain;
  final SignalTrust trust;
  const WebSignal(this.domain, this.trust);
}

enum AutofillConcern {
  appIdSelfReported,
  appIdFromTitle,
  domainNotOwnedByApp,
  domainUserSelectedOnly,
  domainUncheckable,
  unrecognisedBrowser,
  webContentNotVerifiable,
  focusedDomainUnknown,
  noIdentity,
}

/// What we are filling into. The app id and the website are assessed independently: an entry can match on either
/// and each match carries the trust of the signal that produced it.
@immutable
class AutofillTarget {
  /// The requesting app is one we never fill into (e.g. ourselves). The request is declined.
  final bool excluded;

  /// null = no usable app identity (including when the requesting app is a browser)
  final AppSignal? app;

  /// The domain of the focused field (the only one the plugin will fill), or null if there is no usable one.
  final WebSignal? web;

  /// The requesting app, whatever it is (e.g. the browser). For display only.
  final String? contextAppId;

  /// [contextAppId] was supplied by Android rather than reported by the app itself
  final bool contextAppIdTrusted;

  /// Every other usable domain in the request. For display only: these are never matched or learned and the plugin
  /// does not fill their fields.
  final List<AutofillWebDomain> otherDomains;

  final Set<AutofillConcern> concerns;

  const AutofillTarget({
    this.excluded = false,
    this.app,
    this.web,
    this.contextAppId,
    this.contextAppIdTrusted = false,
    this.otherDomains = const [],
    this.concerns = const {},
  });

  /// Never filled, along with our own package. The plugin already declines these (and anything in the manifest's
  /// EXCLUDED_PACKAGES meta-data) so this is defence in depth.
  static const Set<String> excludedPackages = {'android', 'com.android.settings', 'com.oneplus.applocker'};

  /// [ownPackageName] is the running app's package (which differs between our release channels) so that we never fill
  /// into ourselves.
  factory AutofillTarget.fromMetadata(AutofillMetadata metadata, {required String ownPackageName}) {
    final appId = metadata.appId?.trim() ?? '';
    final contextAppId = appId.isEmpty ? null : appId;

    if (appId == ownPackageName || excludedPackages.contains(appId)) {
      return AutofillTarget(excluded: true, contextAppId: contextAppId);
    }

    // An id with no recorded source is treated like the least reliable one
    final source = appId.isEmpty
        ? AppIdSource.none
        : metadata.appIdSource == AppIdSource.none
        ? AppIdSource.windowTitle
        : metadata.appIdSource;
    final appIdTrusted = source == AppIdSource.component;

    final concerns = <AutofillConcern>{};

    // appIsBrowser can be derived from a self-reported id or a self-declared https intent filter, so when the id is
    // untrusted we raise only the id concern and never call it a browser.
    AppSignal? app;
    if (appId.isNotEmpty) {
      if (appIdTrusted) {
        if (!metadata.appIsBrowser) app = AppSignal(appId, SignalTrust.verified, source);
      } else {
        if (!metadata.appIsBrowser) app = AppSignal(appId, SignalTrust.unverified, source);
        concerns.add(
          source == AppIdSource.viewNode ? AutofillConcern.appIdSelfReported : AutofillConcern.appIdFromTitle,
        );
      }
    }

    // Only the focused domain can be matched or learned. The plugin fills nothing outside it.
    WebSignal? web;
    final domains = metadata.webDomains.where((d) => d.domain.trim().isNotEmpty).toList();
    final focusedCandidate = metadata.focusedWebDomain;
    final focused = focusedCandidate != null && isUsableDomain(focusedCandidate.domain) ? focusedCandidate : null;
    final otherDomains = domains.where((d) => !identical(d, focusedCandidate) && isUsableDomain(d.domain)).toList();
    if (domains.isEmpty) {
      // API 29/30 strip the domains of non-browser apps while leaving isWebOrigin set
      if (metadata.isWebOrigin) concerns.add(AutofillConcern.webContentNotVerifiable);
    } else if (focused == null) {
      concerns.add(AutofillConcern.focusedDomainUnknown);
    } else if (focused.dalVerified) {
      web = WebSignal(focused, SignalTrust.verified);
    } else {
      web = WebSignal(focused, SignalTrust.unverified);
      concerns.add(
        focused.userSelected
            ? AutofillConcern.domainUserSelectedOnly
            : !appIdTrusted
            ? AutofillConcern.domainUncheckable
            : metadata.appIsBrowser
            ? AutofillConcern.unrecognisedBrowser
            : AutofillConcern.domainNotOwnedByApp,
      );
    }

    if (app == null && web == null && concerns.isEmpty) {
      concerns.add(AutofillConcern.noIdentity);
    }

    return AutofillTarget(
      app: app,
      web: web,
      contextAppId: contextAppId,
      contextAppIdTrusted: appIdTrusted,
      otherDomains: otherDomains,
      concerns: concerns,
    );
  }

  /// A host we can match against and safely learn: it has a registrable domain or is an IP address. Rules out
  /// e.g. the literal "null" host that an opaque (sandboxed iframe) origin would produce.
  @visibleForTesting
  static bool isUsableDomain(String domain) {
    final host = domain.trim();
    if (host.isEmpty) return false;
    if (UrlMatcher._isIpAddress(host)) return true;
    return urls.parse('https://$host')?.publicSuffixUrl.domain != null;
  }

  /// A notice is shown to the user but does not count as a reason to distrust the target
  bool isNotice(AutofillConcern concern) =>
      concern == AutofillConcern.focusedDomainUnknown && app?.trust == SignalTrust.verified;

  /// The concerns that are reasons for distrust, i.e. [concerns] without the notices
  Set<AutofillConcern> get warnings => concerns.where((c) => !isNotice(c)).toSet();

  /// Android identified the requesting app as a browser
  bool get inTrustedBrowser => app == null && contextAppIdTrusted;

  /// Another site in the same request, on a different registrable domain from the focused one, or null. When the
  /// focused domain is an embedded frame (e.g. a sign-in or payment provider) this is likely to be the page the user
  /// thinks they are on, so they may expect entries saved for it to match.
  String? get surroundingSite {
    final web = this.web;
    if (web == null) return null;
    final focused = _registrableDomain(web.domain.domain);
    return otherDomains.map((d) => d.domain.trim()).firstWhereOrNull((d) => _registrableDomain(d) != focused);
  }

  static String _registrableDomain(String host) {
    final h = host.trim().toLowerCase();
    if (UrlMatcher._isIpAddress(h)) return h;
    return urls.parse('https://$h')?.publicSuffixUrl.domain?.toLowerCase() ?? h;
  }

  bool get hasVerifiedSignal => app?.trust == SignalTrust.verified || web?.trust == SignalTrust.verified;

  /// Nothing about the target is verified (no identity at all, or only unverified ones such as an unrecognised browser
  /// or a link setting) so the user must confirm before we fill anything.
  bool get requiresConfirmation => !hasVerifiedSignal;

  /// The user must confirm before we fill [match] (null for an entry that did not match): whenever
  /// [requiresConfirmation], and also when the entry matched only through a website that the verified app has not
  /// been shown to own, because that is exactly how a fake app showing a copy of a real site would look.
  bool requiresConfirmationFor(AutofillMatch? match) =>
      requiresConfirmation || match?.tier == AutofillMatchTier.unverified;

  /// Short human-readable name for the target, or null if we don't know what it is.
  String? get displayName => web?.domain.domain ?? app?.appId;

  /// The queue item that records what to learn about [entryUuid] when the user chooses it, or null if nothing should be
  /// written. Each signal is decided on its own:
  ///  - the app id is learned when verified (a browser's id is never present as an app signal);
  ///  - the website is learned when verified, or when unverified but inside a verified app and the user opted in.
  /// [web] is only ever the focused domain, which is the only one the plugin fills. [otherDomains] are deliberately
  /// never learned, even when Android verified them.
  /// A signal that already matched at full strength is skipped so we don't dirty the vault for nothing.
  Map<String, dynamic>? associationFor(String entryUuid, AutofillMatch? match, {bool linkUnverifiedDomain = false}) {
    final app = this.app;
    final web = this.web;

    final learnApp = app != null && app.trust == SignalTrust.verified && !(match?.appMatched ?? false);

    final webAllowed =
        web != null &&
        (web.trust == SignalTrust.verified ||
            (linkUnverifiedDomain && app != null && app.trust == SignalTrust.verified));
    final learnWeb = webAllowed && match?.webMatched != WebMatchStrength.exactHost;

    if (!learnApp && !learnWeb) return null;

    return {
      'domain': learnWeb ? web.domain.domain : '',
      'scheme': learnWeb ? web.domain.scheme : null,
      'entry': entryUuid,
      'appId': learnApp ? app.appId : '',
    };
  }
}

enum WebMatchStrength { exactHost, domain }

enum AutofillMatchTier { appAndSite, strong, domain, unverified }

@immutable
class AutofillMatch {
  final KdbxEntry entry;
  final bool appMatched;
  final WebMatchStrength? webMatched;

  /// The host of the entry URL that produced [webMatched]
  final String? matchedUrlHost;
  final bool appVerified;
  final bool webVerified;
  final AutofillMatchTier tier;

  const AutofillMatch._({
    required this.entry,
    required this.appMatched,
    required this.webMatched,
    required this.matchedUrlHost,
    required this.appVerified,
    required this.webVerified,
    required this.tier,
  });

  /// The match came through the verified app signal
  bool get viaVerifiedApp => appMatched && appVerified;

  /// The URL matched but we could not verify the website (or the app showing it)
  bool get hasUnverifiedWebMatch => webMatched != null && !webVerified;

  static AutofillMatchTier _tierFor({
    required bool appMatched,
    required bool appVerified,
    required WebMatchStrength? webMatched,
    required bool webVerified,
  }) {
    final verifiedApp = appMatched && appVerified;
    final verifiedExact = webVerified && webMatched == WebMatchStrength.exactHost;
    final verifiedDomain = webVerified && webMatched == WebMatchStrength.domain;
    if (verifiedApp && verifiedExact) return AutofillMatchTier.appAndSite;
    if (verifiedApp || verifiedExact) return AutofillMatchTier.strong;
    if (verifiedDomain) return AutofillMatchTier.domain;
    return AutofillMatchTier.unverified;
  }
}

/// The matches for one autofill request, computed once because the vault cannot change while autofilling.
@immutable
class AutofillMatches {
  /// Ordered by tier. Entries within a tier keep the order in which they were supplied.
  final List<AutofillMatch> ordered;
  final Map<String, AutofillMatch> byUuid;

  const AutofillMatches._(this.ordered, this.byUuid);

  static const AutofillMatches empty = AutofillMatches._([], {});

  bool get isEmpty => ordered.isEmpty;

  AutofillMatch? operator [](String uuid) => byUuid[uuid];

  factory AutofillMatches.compute(AutofillTarget target, Iterable<KdbxEntry> entries, KdbxFile? vaultFile) {
    final request = _WebRequest.tryCreate(target.web, vaultFile);
    final app = target.app;
    final web = target.web;
    if (app == null && (web == null || request == null)) return empty;

    final matches = <AutofillMatch>[];
    for (final entry in entries) {
      final match = _evaluate(target, entry, request);
      if (match != null) matches.add(match);
    }
    // mergeSort is stable
    mergeSort(matches, compare: (a, b) => a.tier.index.compareTo(b.tier.index));
    return AutofillMatches._(matches, {for (final m in matches) m.entry.uuid.uuid: m});
  }

  static AutofillMatch? _evaluate(AutofillTarget target, KdbxEntry entry, _WebRequest? request) {
    final settings = entry.browserSettings;
    if (settings.matcherConfigs.any((mc) => mc.matcherType == EntryMatcherType.Hide)) {
      return null;
    }

    final app = target.app;
    final web = target.web;
    final accuracy =
        request?.accuracyOverride ??
        settings.matcherConfigs.firstWhereOrNull((mc) => mc.matcherType == EntryMatcherType.Url)?.urlMatchMethod ??
        MatchAccuracy.Domain;

    WebMatchStrength? webMatched;
    String? matchedUrlHost;
    if (web != null && request != null) {
      // Exclusions apply to the whole entry, including any match through the app id
      for (final p in settings.excludeUrls) {
        if (p is String &&
            UrlMatcher.classifyUrl(p, accuracy, request.scheme, request.hostname, request.registrableDomain) != null) {
          return null;
        }
      }

      final patterns = <String>[];
      final primaryUrl = entry.getString(KdbxKeyCommon.URL)?.getText();
      if (primaryUrl != null) patterns.add(primaryUrl);
      for (final p in settings.includeUrls) {
        if (p is String) patterns.add(p);
      }
      for (final pattern in patterns) {
        final strength = UrlMatcher.classifyUrl(
          pattern,
          accuracy,
          request.scheme,
          request.hostname,
          request.registrableDomain,
        );
        if (strength == null) continue;
        if (webMatched == null || strength.index < webMatched.index) {
          webMatched = strength;
          matchedUrlHost = urls.parse(pattern.trim())?.publicSuffixUrl.sourceUrl.host;
        }
      }
    }

    final appMatched = app != null && entry.androidPackageNames.any((n) => n.toLowerCase() == app.appId.toLowerCase());

    if (!appMatched && webMatched == null) return null;

    final appVerified = app?.trust == SignalTrust.verified;
    final webVerified = web?.trust == SignalTrust.verified;
    return AutofillMatch._(
      entry: entry,
      appMatched: appMatched,
      webMatched: webMatched,
      matchedUrlHost: matchedUrlHost,
      appVerified: appVerified,
      webVerified: webVerified,
      tier: AutofillMatch._tierFor(
        appMatched: appMatched,
        appVerified: appVerified,
        webMatched: webMatched,
        webVerified: webVerified,
      ),
    );
  }
}

class _WebRequest {
  final String scheme;
  final String hostname;
  final String registrableDomain;
  final MatchAccuracy? accuracyOverride;

  _WebRequest(this.scheme, this.hostname, this.registrableDomain, this.accuracyOverride);

  static _WebRequest? tryCreate(WebSignal? web, KdbxFile? vaultFile) {
    if (web == null) return null;
    final requestedUrl = urls.parse('${web.domain.scheme ?? 'https'}://${web.domain.domain}'.trim());
    if (requestedUrl == null) return null;

    final hostname = requestedUrl.publicSuffixUrl.sourceUrl.host;
    final registrableDomain = requestedUrl.publicSuffixUrl.domain;
    final scheme = requestedUrl.publicSuffixUrl.sourceUrl.scheme;
    if (registrableDomain == null) return null;

    // Domain-specific match accuracy override from vault metadata
    final override = vaultFile == null
        ? null
        : MatchAccuracy.values.singleWhereOrNull(
            (val) => val.name == vaultFile.body.meta.browserSettings.matchedURLAccuracyOverrides[registrableDomain],
          );
    return _WebRequest(scheme, hostname, registrableDomain, override);
  }
}

class UrlMatcher {
  /// How closely [pattern] (a URL from an entry) matches the requested site, or null if it doesn't.
  /// Comparisons are case-insensitive equality; never substring matching (bank.com must not match evilbank.com).
  static WebMatchStrength? classifyUrl(
    String pattern,
    MatchAccuracy minimumMatchAccuracy,
    String scheme,
    String hostname,
    String registrableDomain,
  ) {
    final testUrl = urls.parse(pattern.trim());
    if (testUrl == null) {
      // If the user has not supplied a valid URL, we cannot safely permit it to match anything
      return null;
    }
    if (scheme == 'http' && testUrl.publicSuffixUrl.sourceUrl.scheme == 'https') {
      // Prevent matching secure URLs in entries with an insecure version of the website but not vice-versa
      return null;
    }

    final host = testUrl.publicSuffixUrl.sourceUrl.host;
    if (host.toLowerCase() == hostname.toLowerCase()) return WebMatchStrength.exactHost;

    // If user has requested Exact, we use Hostname matching instead since it is stricter than Domain, but unfortunately
    // we don't have the required information from Android to be able to perform the exact match the user requested.
    // IP addresses have no registrable domain (the public suffix list would treat 1.2.3.4 as domain "3.4")
    // so they must always be compared in full.
    if (minimumMatchAccuracy == MatchAccuracy.Domain && !_isIpAddress(host)) {
      final domain = testUrl.publicSuffixUrl.domain ?? host;
      if (domain.toLowerCase() == registrableDomain.toLowerCase()) return WebMatchStrength.domain;
    }
    return null;
  }

  @visibleForTesting
  static bool urlsMatch(
    String pattern,
    MatchAccuracy minimumMatchAccuracy,
    String scheme,
    String hostname,
    String registrableDomain,
  ) => classifyUrl(pattern, minimumMatchAccuracy, scheme, hostname, registrableDomain) != null;

  static bool _isIpAddress(String host) {
    final unbracketed = host.startsWith('[') && host.endsWith(']') ? host.substring(1, host.length - 1) : host;
    return InternetAddress.tryParse(unbracketed) != null;
  }
}
