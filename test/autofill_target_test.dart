import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/autofill_matching.dart';

AutofillMetadata metadata({
  String? appId,
  bool appIdTrusted = true,
  bool appIsBrowser = false,
  List<String> domains = const [],
  bool isWebOrigin = false,
  bool? dalVerified,
}) => AutofillMetadata(
  appId: appId,
  appIdTrusted: appIdTrusted,
  appIsBrowser: appIsBrowser,
  webDomains: {for (final d in domains) AutofillWebDomain(scheme: 'https', domain: d)},
  isWebOrigin: isWebOrigin || domains.isNotEmpty,
  // Android reports true when there is no web origin
  dalVerified: dalVerified ?? !(isWebOrigin || domains.isNotEmpty),
  saveInfo: null,
);

void main() {
  group('AutofillTarget app signal', () {
    test('empty app id: no app and noIdentity when there is no web signal either', () {
      final t = AutofillTarget.fromMetadata(metadata(appId: ''));
      expect(t.app, isNull);
      expect(t.web, isNull);
      expect(t.concerns, {AutofillConcern.noIdentity});
      expect(t.requiresConfirmation, true);
    });
    test('missing app id is the same as empty', () {
      final t = AutofillTarget.fromMetadata(metadata());
      expect(t.app, isNull);
      expect(t.concerns, {AutofillConcern.noIdentity});
    });
    test('browser: no app signal, id kept as context only', () {
      final t = AutofillTarget.fromMetadata(
        metadata(appId: 'com.android.chrome', appIsBrowser: true, domains: ['example.com'], dalVerified: true),
      );
      expect(t.app, isNull);
      expect(t.contextAppId, 'com.android.chrome');
      expect(t.concerns, isEmpty);
    });
    test('app id taken from the window title: unverified with appIdFromTitle', () {
      final t = AutofillTarget.fromMetadata(metadata(appId: 'Some Title', appIdTrusted: false));
      expect(t.app?.trust, SignalTrust.unverified);
      expect(t.app?.appId, 'Some Title');
      expect(t.concerns, {AutofillConcern.appIdFromTitle});
      expect(t.hasVerifiedSignal, false);
      expect(t.requiresConfirmation, false);
    });
    test('trusted app id: verified, no concerns', () {
      final t = AutofillTarget.fromMetadata(metadata(appId: 'com.example.app'));
      expect(t.app?.trust, SignalTrust.verified);
      expect(t.concerns, isEmpty);
      expect(t.hasVerifiedSignal, true);
      expect(t.requiresConfirmation, false);
    });
    test('our own package is excluded', () {
      final t = AutofillTarget.fromMetadata(metadata(appId: 'com.keevault.keevault'));
      expect(t.excluded, true);
      expect(t.app, isNull);
      expect(t.web, isNull);
    });
    test('other excluded packages', () {
      for (final id in ['android', 'com.android.settings', 'com.oneplus.applocker']) {
        expect(AutofillTarget.fromMetadata(metadata(appId: id)).excluded, true, reason: id);
      }
    });
  });

  group('AutofillTarget web signal', () {
    test('several domains: no web signal and multipleDomains', () {
      final t = AutofillTarget.fromMetadata(
        metadata(appId: 'com.android.chrome', appIsBrowser: true, domains: ['a.com', 'b.com'], dalVerified: true),
      );
      expect(t.web, isNull);
      expect(t.concerns, {AutofillConcern.multipleDomains});
      expect(t.requiresConfirmation, true);
    });
    test('domains stripped on old Android: webContentNotVerifiable', () {
      final t = AutofillTarget.fromMetadata(metadata(appId: 'com.example.app', isWebOrigin: true, dalVerified: false));
      expect(t.web, isNull);
      expect(t.concerns, {AutofillConcern.webContentNotVerifiable});
      expect(t.app?.trust, SignalTrust.verified);
    });
    test('no web content at all: no web signal and no concern', () {
      final t = AutofillTarget.fromMetadata(metadata(appId: 'com.example.app'));
      expect(t.web, isNull);
      expect(t.concerns, isEmpty);
    });
    test('one DAL verified domain: verified', () {
      final t = AutofillTarget.fromMetadata(
        metadata(appId: 'com.example.app', domains: ['example.com'], dalVerified: true),
      );
      expect(t.web?.trust, SignalTrust.verified);
      expect(t.web?.domain.domain, 'example.com');
      expect(t.concerns, isEmpty);
    });
    test('unverified domain in a browser: unrecognisedBrowser', () {
      final t = AutofillTarget.fromMetadata(
        metadata(appId: 'org.niche.browser', appIsBrowser: true, domains: ['example.com'], dalVerified: false),
      );
      expect(t.app, isNull);
      expect(t.web?.trust, SignalTrust.unverified);
      expect(t.concerns, {AutofillConcern.unrecognisedBrowser});
    });
    test('unverified domain in a non-browser app: domainNotOwnedByApp', () {
      final t = AutofillTarget.fromMetadata(
        metadata(appId: 'com.example.app', domains: ['login.microsoftonline.com'], dalVerified: false),
      );
      expect(t.web?.trust, SignalTrust.unverified);
      expect(t.concerns, {AutofillConcern.domainNotOwnedByApp});
    });
    test('blank domain is ignored', () {
      final t = AutofillTarget.fromMetadata(metadata(appId: 'com.example.app', domains: [' ']));
      expect(t.web, isNull);
    });
  });

  group('situations and what is learned on selection', () {
    Map<String, dynamic>? learned(AutofillTarget t, {bool alsoLink = false}) =>
        t.associationFor('entry-uuid', null, linkUnverifiedDomain: alsoLink);

    test('browser on a verified site: learns the domain only', () {
      final t = AutofillTarget.fromMetadata(
        metadata(appId: 'com.android.chrome', appIsBrowser: true, domains: ['example.com'], dalVerified: true),
      );
      expect(learned(t), {'domain': 'example.com', 'scheme': 'https', 'entry': 'entry-uuid', 'appId': ''});
    });

    test('native app without web content: learns the app id only', () {
      final t = AutofillTarget.fromMetadata(metadata(appId: 'com.example.app'));
      expect(learned(t), {'domain': '', 'scheme': null, 'entry': 'entry-uuid', 'appId': 'com.example.app'});
    });

    test('WebView signing in on another domain: learns the app id, the domain only if the user opts in', () {
      final t = AutofillTarget.fromMetadata(
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
      final t = AutofillTarget.fromMetadata(
        metadata(appId: 'com.example.app', domains: ['example.com'], dalVerified: true),
      );
      expect(learned(t), {
        'domain': 'example.com',
        'scheme': 'https',
        'entry': 'entry-uuid',
        'appId': 'com.example.app',
      });
    });

    test('unrecognised browser: learns nothing, even if the "also link" switch is on', () {
      final t = AutofillTarget.fromMetadata(
        metadata(appId: 'org.niche.browser', appIsBrowser: true, domains: ['example.com'], dalVerified: false),
      );
      expect(learned(t), isNull);
      expect(learned(t, alsoLink: true), isNull);
    });

    test('app id from the window title is never learned', () {
      final t = AutofillTarget.fromMetadata(metadata(appId: 'Some Title', appIdTrusted: false));
      expect(learned(t), isNull);
    });

    test('multi-origin page or no identity: nothing learned and confirmation required', () {
      final multi = AutofillTarget.fromMetadata(
        metadata(appId: 'com.android.chrome', appIsBrowser: true, domains: ['a.com', 'b.com'], dalVerified: true),
      );
      final none = AutofillTarget.fromMetadata(metadata());
      for (final t in [multi, none]) {
        expect(t.requiresConfirmation, true);
        expect(learned(t), isNull);
        expect(learned(t, alsoLink: true), isNull);
      }
    });
  });
}
