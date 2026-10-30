import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/autofill_matching.dart';
import 'package:public_suffix/public_suffix.dart';

/// As Kee Vault's release build would see it
AutofillTarget fromMetadata(AutofillMetadata metadata, {String ownPackageName = 'com.keevault.keevault'}) =>
    AutofillTarget.fromMetadata(metadata, ownPackageName: ownPackageName);

AutofillWebDomain dom(String domain, {bool dal = false, bool userSelected = false, bool focused = false}) =>
    AutofillWebDomain(scheme: 'https', domain: domain, dalVerified: dal, userSelected: userSelected, focused: focused);

/// [domains] all get [dalVerified] and, if there is exactly one, it is the focused one. Use [webDomains] for anything
/// more specific.
AutofillMetadata metadata({
  String? appId,
  AppIdSource source = AppIdSource.component,
  bool appIsBrowser = false,
  List<String> domains = const [],
  bool dalVerified = false,
  List<AutofillWebDomain>? webDomains,
  bool isWebOrigin = false,
}) {
  final all = webDomains ?? [for (final d in domains) dom(d, dal: dalVerified, focused: domains.length == 1)];
  return AutofillMetadata(
    appId: appId,
    appIdSource: appId == null ? AppIdSource.none : source,
    appIsBrowser: appIsBrowser,
    webDomains: all.toSet(),
    isWebOrigin: isWebOrigin || all.isNotEmpty,
    saveInfo: null,
  );
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  DefaultSuffixRules.initFromString(await rootBundle.loadString('assets/public_suffix_list.dat'));

  group('AutofillTarget app signal', () {
    test('empty app id: no app and noIdentity when there is no web signal either', () {
      final t = fromMetadata(metadata(appId: ''));
      expect(t.app, isNull);
      expect(t.web, isNull);
      expect(t.concerns, {AutofillConcern.noIdentity});
      expect(t.requiresConfirmation, true);
    });
    test('missing app id is the same as empty', () {
      final t = fromMetadata(metadata());
      expect(t.app, isNull);
      expect(t.concerns, {AutofillConcern.noIdentity});
    });
    test('browser: no app signal, id kept as context only', () {
      final t = fromMetadata(
        metadata(appId: 'com.android.chrome', appIsBrowser: true, domains: ['example.com'], dalVerified: true),
      );
      expect(t.app, isNull);
      expect(t.contextAppId, 'com.android.chrome');
      expect(t.concerns, isEmpty);
    });
    test('app id taken from the window title: unverified with appIdFromTitle', () {
      final t = fromMetadata(metadata(appId: 'Some Title', source: AppIdSource.windowTitle));
      expect(t.app?.trust, SignalTrust.unverified);
      expect(t.app?.appId, 'Some Title');
      expect(t.concerns, {AutofillConcern.appIdFromTitle});
      expect(t.hasVerifiedSignal, false);
      expect(t.requiresConfirmation, true);
    });
    test('trusted app id: verified, no concerns', () {
      final t = fromMetadata(metadata(appId: 'com.example.app'));
      expect(t.app?.trust, SignalTrust.verified);
      expect(t.concerns, isEmpty);
      expect(t.hasVerifiedSignal, true);
      expect(t.requiresConfirmation, false);
    });
    test('our own package is excluded', () {
      final t = fromMetadata(metadata(appId: 'com.keevault.keevault'));
      expect(t.excluded, true);
      expect(t.app, isNull);
      expect(t.web, isNull);
    });
    test('other excluded packages', () {
      for (final id in ['android', 'com.android.settings', 'com.oneplus.applocker']) {
        expect(fromMetadata(metadata(appId: id)).excluded, true, reason: id);
      }
    });
  });

  group('AutofillTarget web signal', () {
    test('several domains, none focused: no web signal and focusedDomainUnknown', () {
      final t = fromMetadata(
        metadata(appId: 'com.android.chrome', appIsBrowser: true, domains: ['a.com', 'b.com'], dalVerified: true),
      );
      expect(t.web, isNull);
      expect(t.concerns, {AutofillConcern.focusedDomainUnknown});
      expect(t.requiresConfirmation, true);
    });
    test('domains stripped on old Android: webContentNotVerifiable', () {
      final t = fromMetadata(metadata(appId: 'com.example.app', isWebOrigin: true));
      expect(t.web, isNull);
      expect(t.concerns, {AutofillConcern.webContentNotVerifiable});
      expect(t.app?.trust, SignalTrust.verified);
    });
    test('no web content at all: no web signal and no concern', () {
      final t = fromMetadata(metadata(appId: 'com.example.app'));
      expect(t.web, isNull);
      expect(t.concerns, isEmpty);
    });
    test('one DAL verified domain: verified', () {
      final t = fromMetadata(metadata(appId: 'com.example.app', domains: ['example.com'], dalVerified: true));
      expect(t.web?.trust, SignalTrust.verified);
      expect(t.web?.domain.domain, 'example.com');
      expect(t.concerns, isEmpty);
    });
    test('unverified domain in a browser: unrecognisedBrowser', () {
      final t = fromMetadata(
        metadata(appId: 'org.niche.browser', appIsBrowser: true, domains: ['example.com'], dalVerified: false),
      );
      expect(t.app, isNull);
      expect(t.web?.trust, SignalTrust.unverified);
      expect(t.concerns, {AutofillConcern.unrecognisedBrowser});
    });
    test('unverified domain in a non-browser app: domainNotOwnedByApp', () {
      final t = fromMetadata(
        metadata(appId: 'com.example.app', domains: ['login.microsoftonline.com'], dalVerified: false),
      );
      expect(t.web?.trust, SignalTrust.unverified);
      expect(t.concerns, {AutofillConcern.domainNotOwnedByApp});
    });
    test('blank domain is ignored', () {
      final t = fromMetadata(metadata(appId: 'com.example.app', domains: [' ']));
      expect(t.web, isNull);
    });
  });

  group('situations and what is learned on selection', () {
    Map<String, dynamic>? learned(AutofillTarget t, {bool alsoLink = false}) =>
        t.associationFor('entry-uuid', null, linkUnverifiedDomain: alsoLink);

    test('browser on a verified site: learns the domain only', () {
      final t = fromMetadata(
        metadata(appId: 'com.android.chrome', appIsBrowser: true, domains: ['example.com'], dalVerified: true),
      );
      expect(learned(t), {'domain': 'example.com', 'scheme': 'https', 'entry': 'entry-uuid', 'appId': ''});
    });

    test('native app without web content: learns the app id only', () {
      final t = fromMetadata(metadata(appId: 'com.example.app'));
      expect(learned(t), {'domain': '', 'scheme': null, 'entry': 'entry-uuid', 'appId': 'com.example.app'});
    });

    test('WebView signing in on another domain: learns the app id, the domain only if the user opts in', () {
      final t = fromMetadata(
        metadata(appId: 'com.example.app', domains: ['login.microsoftonline.com'], dalVerified: false),
      );
      expect(t.app?.trust, SignalTrust.verified);
      expect(t.web?.trust, SignalTrust.unverified);
      expect(learned(t), {'domain': '', 'scheme': null, 'entry': 'entry-uuid', 'appId': 'com.example.app'});
      expect(learned(t, alsoLink: true), {
        'domain': 'login.microsoftonline.com',
        'scheme': 'https',
        'entry': 'entry-uuid',
        'appId': 'com.example.app',
      });
    });

    test('app with its own DAL verified domain: learns both', () {
      final t = fromMetadata(metadata(appId: 'com.example.app', domains: ['example.com'], dalVerified: true));
      expect(learned(t), {
        'domain': 'example.com',
        'scheme': 'https',
        'entry': 'entry-uuid',
        'appId': 'com.example.app',
      });
    });

    test('unrecognised browser: learns nothing, even if the "also link" switch is on', () {
      final t = fromMetadata(
        metadata(appId: 'org.niche.browser', appIsBrowser: true, domains: ['example.com'], dalVerified: false),
      );
      expect(learned(t), isNull);
      expect(learned(t, alsoLink: true), isNull);
    });

    test('app id from the window title is never learned', () {
      final t = fromMetadata(metadata(appId: 'Some Title', source: AppIdSource.windowTitle));
      expect(learned(t), isNull);
    });

    test('nothing focused in a browser or no identity: nothing learned and confirmation required', () {
      final multi = fromMetadata(
        metadata(appId: 'com.android.chrome', appIsBrowser: true, domains: ['a.com', 'b.com'], dalVerified: true),
      );
      final none = fromMetadata(metadata());
      for (final t in [multi, none]) {
        expect(t.requiresConfirmation, true);
        expect(learned(t), isNull);
        expect(learned(t, alsoLink: true), isNull);
      }
    });
  });

  group('app id source', () {
    test('view node id: unverified app with appIdSelfReported', () {
      final t = fromMetadata(metadata(appId: 'com.bank.app', source: AppIdSource.viewNode));
      expect(t.app?.trust, SignalTrust.unverified);
      expect(t.app?.source, AppIdSource.viewNode);
      expect(t.contextAppIdTrusted, false);
      expect(t.concerns, {AutofillConcern.appIdSelfReported});
      expect(t.requiresConfirmation, true);
      expect(t.associationFor('entry-uuid', null), isNull);
    });
    test('window title id: appIdFromTitle', () {
      final t = fromMetadata(metadata(appId: 'Some Title', source: AppIdSource.windowTitle));
      expect(t.app?.source, AppIdSource.windowTitle);
      expect(t.concerns, {AutofillConcern.appIdFromTitle});
    });
    test('view node id claiming to be a browser: no app, self-reported, never called a browser', () {
      final t = fromMetadata(
        metadata(appId: 'com.android.chrome', source: AppIdSource.viewNode, appIsBrowser: true, domains: ['bank.com']),
      );
      expect(t.app, isNull);
      expect(t.contextAppId, 'com.android.chrome');
      expect(t.contextAppIdTrusted, false);
      expect(t.inTrustedBrowser, false);
      expect(t.concerns, {AutofillConcern.appIdSelfReported, AutofillConcern.domainUncheckable});
      expect(t.concerns, isNot(contains(AutofillConcern.unrecognisedBrowser)));
      expect(t.requiresConfirmation, true);
    });
    test('component id of a browser: trusted context, no app signal', () {
      final t = fromMetadata(
        metadata(appId: 'com.android.chrome', appIsBrowser: true, domains: ['bank.com'], dalVerified: true),
      );
      expect(t.contextAppIdTrusted, true);
      expect(t.inTrustedBrowser, true);
    });
    test('view node id with a focused domain: domainUncheckable', () {
      final t = fromMetadata(metadata(appId: 'com.bank.app', source: AppIdSource.viewNode, domains: ['www.bank.com']));
      expect(t.web?.trust, SignalTrust.unverified);
      expect(t.concerns, {AutofillConcern.appIdSelfReported, AutofillConcern.domainUncheckable});
    });
  });

  group('focused domain', () {
    test('browser with three domains, the focused one verified: no concerns, others for display only', () {
      final t = fromMetadata(
        metadata(
          appId: 'com.android.chrome',
          appIsBrowser: true,
          webDomains: [dom('a.com', dal: true), dom('www.bank.com', dal: true, focused: true), dom('c.com', dal: true)],
        ),
      );
      expect(t.web?.domain.domain, 'www.bank.com');
      expect(t.web?.trust, SignalTrust.verified);
      expect(t.otherDomains.map((d) => d.domain), unorderedEquals(['a.com', 'c.com']));
      expect(t.concerns, isEmpty);
      expect(t.requiresConfirmation, false);
    });
    test('embedded frame: the focused host is the target and the page around it is the surrounding site', () {
      final t = fromMetadata(
        metadata(
          appId: 'com.android.chrome',
          appIsBrowser: true,
          webDomains: [dom('shop.com', dal: true), dom('login.idp.com', dal: true, focused: true)],
        ),
      );
      expect(t.displayName, 'login.idp.com');
      expect(t.surroundingSite, 'shop.com');
    });
    test('other domains on the same registrable domain are not a surrounding site', () {
      final t = fromMetadata(
        metadata(
          appId: 'com.android.chrome',
          appIsBrowser: true,
          webDomains: [dom('static.bank.com', dal: true), dom('www.bank.com', dal: true, focused: true)],
        ),
      );
      expect(t.otherDomains, hasLength(1));
      expect(t.surroundingSite, isNull);
    });
    test('opaque origin "null" focused in an allowlisted browser: unusable, nothing matched or learned', () {
      final t = fromMetadata(
        metadata(
          appId: 'com.android.chrome',
          appIsBrowser: true,
          webDomains: [dom('null', dal: true, focused: true), dom('shop.com', dal: true)],
        ),
      );
      expect(t.web, isNull);
      expect(t.concerns, {AutofillConcern.focusedDomainUnknown});
      expect(t.otherDomains.map((d) => d.domain), ['shop.com']);
      expect(t.associationFor('entry-uuid', null), isNull);
      expect(t.associationFor('entry-uuid', null, linkUnverifiedDomain: true), isNull);
    });
    test('"null" is never listed as another domain', () {
      final t = fromMetadata(
        metadata(
          appId: 'com.android.chrome',
          appIsBrowser: true,
          webDomains: [dom('null', dal: true), dom('shop.com', dal: true, focused: true)],
        ),
      );
      expect(t.web?.domain.domain, 'shop.com');
      expect(t.otherDomains, isEmpty);
    });
    test('focused domain unverified while another is verified: the verified one is never used', () {
      final t = fromMetadata(
        metadata(
          appId: 'com.example.app',
          webDomains: [dom('example.com', dal: true), dom('login.microsoftonline.com', focused: true)],
        ),
      );
      expect(t.web?.domain.domain, 'login.microsoftonline.com');
      expect(t.web?.trust, SignalTrust.unverified);
      expect(t.concerns, {AutofillConcern.domainNotOwnedByApp});
    });
    test('user selected focused domain inside a verified app: unverified, can only be linked by opting in', () {
      final t = fromMetadata(
        metadata(appId: 'com.example.app', webDomains: [dom('example.com', userSelected: true, focused: true)]),
      );
      expect(t.app?.trust, SignalTrust.verified);
      expect(t.web?.trust, SignalTrust.unverified);
      expect(t.web?.domain.userSelected, true);
      expect(t.concerns, {AutofillConcern.domainUserSelectedOnly});
      expect(t.requiresConfirmation, false);
      expect(t.associationFor('entry-uuid', null)?['domain'], '');
      expect(t.associationFor('entry-uuid', null, linkUnverifiedDomain: true)?['domain'], 'example.com');
    });
    test('no focused domain inside a verified app: a notice only, the app is still matched', () {
      final t = fromMetadata(
        metadata(appId: 'com.bank.app', webDomains: [dom('bank.com', dal: true), dom('ads.example')]),
      );
      expect(t.web, isNull);
      expect(t.app?.trust, SignalTrust.verified);
      expect(t.concerns, {AutofillConcern.focusedDomainUnknown});
      expect(t.isNotice(AutofillConcern.focusedDomainUnknown), true);
      expect(t.warnings, isEmpty);
      expect(t.requiresConfirmation, false);
      expect(t.otherDomains, hasLength(2));
    });
    test('no focused domain in a browser: a warning and confirmation required', () {
      final t = fromMetadata(
        metadata(appId: 'com.android.chrome', appIsBrowser: true, domains: ['a.com', 'b.com'], dalVerified: true),
      );
      expect(t.isNotice(AutofillConcern.focusedDomainUnknown), false);
      expect(t.warnings, {AutofillConcern.focusedDomainUnknown});
      expect(t.requiresConfirmation, true);
    });
    test('associationFor never learns a domain that is not focused, even a verified one', () {
      final t = fromMetadata(
        metadata(
          appId: 'com.example.app',
          webDomains: [dom('example.com', dal: true), dom('login.microsoftonline.com', focused: true)],
        ),
      );
      for (final alsoLink in [false, true]) {
        expect(t.associationFor('entry-uuid', null, linkUnverifiedDomain: alsoLink)?['domain'], isNot('example.com'));
      }
    });
  });

  group('confirmation', () {
    test('required for an unrecognised browser', () {
      final t = fromMetadata(metadata(appId: 'org.niche.browser', appIsBrowser: true, domains: ['example.com']));
      expect(t.requiresConfirmation, true);
    });
    test('required for a link setting domain without a verified app', () {
      final t = fromMetadata(
        metadata(
          appId: 'org.niche.browser',
          appIsBrowser: true,
          webDomains: [dom('example.com', userSelected: true, focused: true)],
        ),
      );
      expect(t.concerns, {AutofillConcern.domainUserSelectedOnly});
      expect(t.requiresConfirmation, true);
    });
    test('not required whenever a signal is verified', () {
      for (final m in [
        metadata(appId: 'com.example.app'),
        metadata(appId: 'com.android.chrome', appIsBrowser: true, domains: ['example.com'], dalVerified: true),
        metadata(appId: 'com.example.app', domains: ['login.microsoftonline.com']),
      ]) {
        expect(fromMetadata(m).requiresConfirmation, false, reason: m.toString());
      }
    });
  });

  group('exclusion', () {
    test('uses the running package name', () {
      expect(
        fromMetadata(
          metadata(appId: 'com.keevault.keevault.debug'),
          ownPackageName: 'com.keevault.keevault.debug',
        ).excluded,
        true,
      );
      expect(fromMetadata(metadata(appId: 'com.keevault.keevault.beta')).excluded, false);
    });
  });
}
