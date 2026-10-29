import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/autofill_matching.dart';
import 'package:public_suffix/public_suffix.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  DefaultSuffixRules.initFromString(await rootBundle.loadString('assets/public_suffix_list.dat'));

  late KdbxFile file;
  late Map<String, KdbxEntry> e;

  KdbxEntry add(
    String name, {
    String? url,
    List<String>? packages,
    List<EntryMatcherConfig>? matchers,
    List<String>? excludeUrls,
  }) {
    final entry = KdbxEntry.create(file, file.body.rootGroup);
    entry.setString(KdbxKeyCommon.TITLE, PlainValue(name));
    if (url != null) entry.setString(KdbxKeyCommon.URL, PlainValue(url));
    if (packages != null) entry.androidPackageNames = packages;
    if (matchers != null || excludeUrls != null) {
      entry.browserSettings = BrowserEntrySettings(matcherConfigs: matchers ?? [], excludeUrls: excludeUrls ?? []);
    }
    file.body.rootGroup.addEntry(entry);
    return entry;
  }

  setUp(() {
    file = KdbxFormat().create(Credentials(ProtectedValue.fromString('test')), 'test');
    e = {
      'exact': add('exact', url: 'https://www.bank.com'),
      'sibling': add('sibling', url: 'https://login.bank.com'),
      'package': add('package', packages: ['com.bank.app']),
      'both': add('both', url: 'https://www.bank.com', packages: ['com.bank.app']),
      'hide': add(
        'hide',
        url: 'https://www.bank.com',
        packages: ['com.bank.app'],
        matchers: [EntryMatcherConfig(matcherType: EntryMatcherType.Hide)],
      ),
      'excluded': add(
        'excluded',
        url: 'https://www.bank.com',
        packages: ['com.bank.app'],
        excludeUrls: ['https://www.bank.com'],
      ),
      'chrome': add('chrome', packages: ['com.android.chrome']),
      'foreign': add('foreign', url: 'https://login.microsoftonline.com'),
      'unrelated': add('unrelated', url: 'https://example.org'),
    };
  });

  AutofillMatches compute(AutofillMetadata metadata) =>
      AutofillMatches.compute(AutofillTarget.fromMetadata(metadata), file.body.rootGroup.getAllEntries().values, file);

  Map<String, AutofillMatchTier> tiers(AutofillMatches m) => {
    for (final match in m.ordered) match.entry.getString(KdbxKeyCommon.TITLE)!.getText(): match.tier,
  };

  AutofillMetadata md({
    String? appId,
    bool trusted = true,
    bool browser = false,
    List<String> domains = const [],
    bool? dal,
  }) => AutofillMetadata(
    appId: appId,
    appIdTrusted: trusted,
    appIsBrowser: browser,
    webDomains: {for (final d in domains) AutofillWebDomain(scheme: 'https', domain: d)},
    isWebOrigin: domains.isNotEmpty,
    dalVerified: dal ?? domains.isEmpty,
    saveInfo: null,
  );

  group('browser request', () {
    test('matches by URL only; a browser package name on an entry never matches', () {
      final m = compute(md(appId: 'com.android.chrome', browser: true, domains: ['www.bank.com'], dal: true));
      expect(tiers(m), {
        'exact': AutofillMatchTier.strong,
        'both': AutofillMatchTier.strong,
        'sibling': AutofillMatchTier.domain,
      });
      expect(m[e['chrome']!.uuid.uuid], isNull);
    });

    test('hidden and excluded entries are not offered, even though they have the URL', () {
      final m = compute(md(appId: 'com.android.chrome', browser: true, domains: ['www.bank.com'], dal: true));
      expect(m[e['hide']!.uuid.uuid], isNull);
      expect(m[e['excluded']!.uuid.uuid], isNull);
    });

    test('exact host beats sibling subdomain in the ordering', () {
      final m = compute(md(appId: 'com.android.chrome', browser: true, domains: ['www.bank.com'], dal: true));
      final order = m.ordered.map((x) => x.tier.index).toList();
      expect(order, [...order]..sort());
      expect(m.ordered.last.entry, e['sibling']);
      expect(m.ordered.last.webMatched, WebMatchStrength.domain);
      expect(m.ordered.last.matchedUrlHost, 'login.bank.com');
    });

    test('look-alike domains do not match', () {
      expect(
        compute(md(appId: 'com.android.chrome', browser: true, domains: ['evilbank.com'], dal: true)).isEmpty,
        true,
      );
      expect(
        compute(md(appId: 'com.android.chrome', browser: true, domains: ['bank.com.evil.net'], dal: true)).isEmpty,
        true,
      );
    });

    test('unrecognised browser: URL matches are unverified', () {
      final m = compute(md(appId: 'org.niche.browser', browser: true, domains: ['www.bank.com'], dal: false));
      expect(tiers(m).values.toSet(), {AutofillMatchTier.unverified});
      expect(tiers(m).keys, containsAll(['exact', 'both', 'sibling']));
    });

    test('multiple origins or no identity: nothing matches', () {
      expect(
        compute(md(appId: 'com.android.chrome', browser: true, domains: ['www.bank.com', 'b.com'], dal: true)).isEmpty,
        true,
      );
      expect(compute(md()).isEmpty, true);
    });
  });

  group('app request', () {
    test('native app matches by package name, strong', () {
      final m = compute(md(appId: 'com.bank.app'));
      // Exclude URLs are only evaluated against a web request, so with no web content the entry is still linked to the app
      expect(tiers(m), {
        'package': AutofillMatchTier.strong,
        'both': AutofillMatchTier.strong,
        'excluded': AutofillMatchTier.strong,
      });
    });

    test('package names compare case-insensitively', () {
      expect(tiers(compute(md(appId: 'COM.Bank.App'))).keys, containsAll(['package', 'both']));
    });

    test('app showing its own DAL verified domain: an entry with both is appAndSite', () {
      final m = compute(md(appId: 'com.bank.app', domains: ['www.bank.com'], dal: true));
      expect(tiers(m), {
        'both': AutofillMatchTier.appAndSite,
        'package': AutofillMatchTier.strong,
        'exact': AutofillMatchTier.strong,
        'sibling': AutofillMatchTier.domain,
      });
      expect(m.ordered.first.entry, e['both']);
    });

    test('WebView signing in on a foreign domain: app-linked entry is strong, domain-only entry is unverified', () {
      e['package']!.setString(KdbxKeyCommon.URL, PlainValue('https://nothing.example'));
      final m = compute(md(appId: 'com.bank.app', domains: ['login.microsoftonline.com'], dal: false));
      expect(tiers(m), {
        'package': AutofillMatchTier.strong,
        'both': AutofillMatchTier.strong,
        'excluded': AutofillMatchTier.strong,
        'foreign': AutofillMatchTier.unverified,
      });
      expect(m[e['foreign']!.uuid.uuid]!.appMatched, false);
      expect(m[e['foreign']!.uuid.uuid]!.webMatched, WebMatchStrength.exactHost);
    });

    test('an entry linked to the app and the foreign domain is still strong via the app', () {
      e['package']!.addAutofillUrl('login.microsoftonline.com', 'https');
      final m = compute(md(appId: 'com.bank.app', domains: ['login.microsoftonline.com'], dal: false));
      final match = m[e['package']!.uuid.uuid]!;
      expect(match.tier, AutofillMatchTier.strong);
      expect(match.viaVerifiedApp, true);
      expect(match.hasUnverifiedWebMatch, true);
    });

    test('app id from the window title: matches are unverified', () {
      final m = compute(md(appId: 'com.bank.app', trusted: false));
      expect(tiers(m).values.toSet(), {AutofillMatchTier.unverified});
    });

    test('excluded URL on the requested site also suppresses an app match', () {
      final m = compute(md(appId: 'com.bank.app', domains: ['www.bank.com'], dal: true));
      expect(m[e['excluded']!.uuid.uuid], isNull);
      expect(m[e['hide']!.uuid.uuid], isNull);
    });
  });

  group('learning skips what already matched at full strength', () {
    test('nothing to write when the app id already matched', () {
      final target = AutofillTarget.fromMetadata(md(appId: 'com.bank.app'));
      final m = AutofillMatches.compute(target, file.body.rootGroup.getAllEntries().values, file);
      expect(target.associationFor(e['package']!.uuid.uuid, m[e['package']!.uuid.uuid]), isNull);
    });

    test('nothing to write when the exact host already matched', () {
      final target = AutofillTarget.fromMetadata(
        md(appId: 'com.android.chrome', browser: true, domains: ['www.bank.com'], dal: true),
      );
      final m = AutofillMatches.compute(target, file.body.rootGroup.getAllEntries().values, file);
      expect(target.associationFor(e['exact']!.uuid.uuid, m[e['exact']!.uuid.uuid]), isNull);
    });

    test('a domain-only match is learned as the exact host', () {
      final target = AutofillTarget.fromMetadata(
        md(appId: 'com.android.chrome', browser: true, domains: ['www.bank.com'], dal: true),
      );
      final m = AutofillMatches.compute(target, file.body.rootGroup.getAllEntries().values, file);
      final item = target.associationFor(e['sibling']!.uuid.uuid, m[e['sibling']!.uuid.uuid]);
      expect(item?['domain'], 'www.bank.com');
    });
  });
}
