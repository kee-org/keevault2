import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:public_suffix/public_suffix.dart';
import 'package:flutter/services.dart' show rootBundle;

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  var suffixList = await rootBundle.loadString('assets/public_suffix_list.dat');
  DefaultSuffixRules.initFromString(suffixList);
  group('Url matching', () {
    test('minimum domain match with correct domain succeeds', () async {
      final result = AutofillCubit.urlsMatch('https://www.test.com', MatchAccuracy.Domain, 'https', 'www.test.com', 'test.com');
      expect(result, true);
    });
    test('minimum domain match with incorrect domain fails', () async {
      final result = AutofillCubit.urlsMatch(
        'https://www.test.com',
        MatchAccuracy.Domain,
        'https',
        'www.test2.com',
        'test2.com',
      );
      expect(result, false);
    });
    test('minimum hostname match with correct hostname succeeds', () async {
      final result = AutofillCubit.urlsMatch(
        'https://www.test.com',
        MatchAccuracy.Hostname,
        'https',
        'www.test.com',
        'test.com',
      );
      expect(result, true);
    });
    test('minimum hostname match with incorrect hostname fails', () async {
      final result = AutofillCubit.urlsMatch(
        'https://www.test.com',
        MatchAccuracy.Hostname,
        'https',
        'www2.test.com',
        'test.com',
      );
      expect(result, false);
    });
    test('minimum hostname match with incorrect domain fails', () async {
      final result = AutofillCubit.urlsMatch(
        'https://www.test.com',
        MatchAccuracy.Hostname,
        'https',
        'www.test2.com',
        'test2.com',
      );
      expect(result, false);
    });
    test('minimum domain match with incorrect hostname succeeds', () async {
      final result = AutofillCubit.urlsMatch(
        'https://www.test.com',
        MatchAccuracy.Domain,
        'https',
        'www2.test.com',
        'test.com',
      );
      expect(result, true);
    });
    test('mismatched scheme on https page succeeds', () async {
      final result = AutofillCubit.urlsMatch('http://www.test.com', MatchAccuracy.Domain, 'https', 'www.test.com', 'test.com');
      expect(result, true);
    });
    test('mismatched scheme on http page fails', () async {
      final result = AutofillCubit.urlsMatch('https://www.test.com', MatchAccuracy.Domain, 'http', 'www.test.com', 'test.com');
      expect(result, false);
    });

    test('minimum domain match with port included succeeds', () async {
      final result = AutofillCubit.urlsMatch(
        'https://www.test.com:1234',
        MatchAccuracy.Domain,
        'https',
        'www.test.com',
        'test.com',
      );
      expect(result, true);
    });
    test('minimum domain match with IPv4 and port succeeds', () async {
      final result = AutofillCubit.urlsMatch('https://1.2.3.4:1234', MatchAccuracy.Domain, 'https', '1.2.3.4', '1.2.3.4');
      expect(result, true);
    });
    test('minimum domain match with IPv6 and port succeeds', () async {
      final result = AutofillCubit.urlsMatch(
        'https://[FEDC:BA98:7654:3210:FEDC:BA98:7654:3210]:1234',
        MatchAccuracy.Domain,
        'https',
        '[FEDC:BA98:7654:3210:FEDC:BA98:7654:3210]',
        '[FEDC:BA98:7654:3210:FEDC:BA98:7654:3210]',
      );
      expect(
        result,
        true,
        skip:
            "Can't test until we know what format Android returns an IPv6 WebDomain in so we need to wait for real world feedback",
      );
    });

    test('minimum domain match with path and correct domain succeeds', () async {
      final result = AutofillCubit.urlsMatch(
        'https://www.test.com/path',
        MatchAccuracy.Domain,
        'https',
        'www.test.com',
        'test.com',
      );
      expect(result, true);
    });
    test('minimum hostname match with path and correct hostname succeeds', () async {
      final result = AutofillCubit.urlsMatch(
        'https://www.test.com/path',
        MatchAccuracy.Domain,
        'https',
        'www.test.com',
        'test.com',
      );
      expect(result, true);
    });

    test('minimum domain match with private hostname, path and correct hostname succeeds', () async {
      final result = AutofillCubit.urlsMatch(
        'https://localmachine/path',
        MatchAccuracy.Domain,
        'https',
        'localmachine',
        'localmachine',
      );
      expect(result, true);
    });
    test('minimum hostname match with private hostname, path and correct hostname succeeds', () async {
      final result = AutofillCubit.urlsMatch(
        'https://localmachine/path',
        MatchAccuracy.Hostname,
        'https',
        'localmachine',
        'localmachine',
      );
      expect(result, true);
    });
  });

  group('Url matching is not substring matching', () {
    test('domain match: bank.com entry does not match evilbank.com', () {
      expect(AutofillCubit.urlsMatch('https://bank.com', MatchAccuracy.Domain, 'https', 'evilbank.com', 'evilbank.com'), false);
    });
    test('domain match: bank.com entry does not match bank.com.evil.net', () {
      expect(
        AutofillCubit.urlsMatch('https://bank.com', MatchAccuracy.Domain, 'https', 'bank.com.evil.net', 'evil.net'),
        false,
      );
    });
    test('hostname match: bank.com entry does not match bank.com.evil.net', () {
      expect(
        AutofillCubit.urlsMatch(
          'https://bank.com',
          MatchAccuracy.Hostname,
          'https',
          'bank.com.evil.net',
          'evil.net',
        ),
        false,
      );
    });
    test('hostname match: bank.com entry does not match evilbank.com', () {
      expect(
        AutofillCubit.urlsMatch('https://bank.com', MatchAccuracy.Hostname, 'https', 'evilbank.com', 'evilbank.com'),
        false,
      );
    });
    test('hostname match: www.bank.com entry does not match notwww.bank.com', () {
      expect(
        AutofillCubit.urlsMatch(
          'https://www.bank.com',
          MatchAccuracy.Hostname,
          'https',
          'notwww.bank.com',
          'bank.com',
        ),
        false,
      );
    });
    test('domain match is case-insensitive', () {
      expect(AutofillCubit.urlsMatch('https://BANK.com', MatchAccuracy.Domain, 'https', 'bank.com', 'bank.com'), true);
      expect(AutofillCubit.urlsMatch('https://bank.com', MatchAccuracy.Domain, 'https', 'BANK.com', 'BANK.com'), true);
    });
    test('hostname match is case-insensitive', () {
      expect(
        AutofillCubit.urlsMatch('https://WWW.bank.com', MatchAccuracy.Hostname, 'https', 'www.bank.com', 'bank.com'),
        true,
      );
      expect(
        AutofillCubit.urlsMatch('https://www.bank.com', MatchAccuracy.Hostname, 'https', 'WWW.BANK.com', 'BANK.com'),
        true,
      );
    });
  });

  group('findMatchingEntries is not substring matching', () {
    late KdbxFile file;

    KdbxEntry addEntry(String url, {MatchAccuracy? accuracy}) {
      final entry = KdbxEntry.create(file, file.body.rootGroup);
      entry.setString(KdbxKeyCommon.URL, PlainValue(url));
      if (accuracy != null) {
        entry.browserSettings = BrowserEntrySettings(
          matcherConfigs: [EntryMatcherConfig.forDefaultUrlMatchBehaviour(accuracy)],
        );
      }
      file.body.rootGroup.addEntry(entry);
      return entry;
    }

    List<KdbxEntry> match(String domain, {String scheme = 'https'}) => AutofillCubit.findMatchingEntries(
      AutofillMetadata(webDomains: {AutofillWebDomain(scheme: scheme, domain: domain)}, saveInfo: null),
      file.body.rootGroup.getAllEntries().values,
      file,
    );

    setUp(() {
      file = KdbxFormat().create(Credentials(ProtectedValue.fromString('test')), 'test');
    });

    test('Domain accuracy: bank.com entry is not offered on evilbank.com', () {
      addEntry('https://bank.com', accuracy: MatchAccuracy.Domain);
      expect(match('evilbank.com'), isEmpty);
    });
    test('Domain accuracy: bank.com entry is not offered on bank.com.evil.net', () {
      addEntry('https://bank.com', accuracy: MatchAccuracy.Domain);
      expect(match('bank.com.evil.net'), isEmpty);
    });
    test('Hostname accuracy: bank.com entry is not offered on bank.com.evil.net', () {
      addEntry('https://bank.com', accuracy: MatchAccuracy.Hostname);
      expect(match('bank.com.evil.net'), isEmpty);
    });
    test('Hostname accuracy: bank.com entry is not offered on evilbank.com', () {
      addEntry('https://bank.com', accuracy: MatchAccuracy.Hostname);
      expect(match('evilbank.com'), isEmpty);
    });
    test('exclude URL is not applied by substring either', () {
      final entry = addEntry('https://bank.com', accuracy: MatchAccuracy.Domain);
      entry.browserSettings = BrowserEntrySettings(
        matcherConfigs: [EntryMatcherConfig.forDefaultUrlMatchBehaviour(MatchAccuracy.Domain)],
        excludeUrls: ['https://bank.com.evil.net'],
      );
      // "bank.com" is a substring of the excluded domain's registrable domain only if matched by substring
      expect(match('bank.com'), [entry]);
    });
    test('differently-cased entry URL still matches', () {
      final entry = addEntry('https://BANK.com', accuracy: MatchAccuracy.Domain);
      expect(match('bank.com'), [entry]);
    });
    test('differently-cased request still matches', () {
      final entry = addEntry('https://bank.com', accuracy: MatchAccuracy.Domain);
      expect(match('BANK.com'), [entry]);
    });
    test('genuine exact domain still matches', () {
      final entry = addEntry('https://bank.com', accuracy: MatchAccuracy.Domain);
      expect(match('bank.com'), [entry]);
    });
  });
}
