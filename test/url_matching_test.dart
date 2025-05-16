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
    final cubit = AutofillCubit();
    test('minimum domain match with correct domain succeeds', () async {
      final result = cubit.urlsMatch('https://www.test.com', MatchAccuracy.Domain, 'https', 'www.test.com', 'test.com');
      expect(result, true);
    });
    test('minimum domain match with incorrect domain fails', () async {
      final result = cubit.urlsMatch(
        'https://www.test.com',
        MatchAccuracy.Domain,
        'https',
        'www.test2.com',
        'test2.com',
      );
      expect(result, false);
    });
    test('minimum hostname match with correct hostname succeeds', () async {
      final result = cubit.urlsMatch(
        'https://www.test.com',
        MatchAccuracy.Hostname,
        'https',
        'www.test.com',
        'test.com',
      );
      expect(result, true);
    });
    test('minimum hostname match with incorrect hostname fails', () async {
      final result = cubit.urlsMatch(
        'https://www.test.com',
        MatchAccuracy.Hostname,
        'https',
        'www2.test.com',
        'test.com',
      );
      expect(result, false);
    });
    test('minimum hostname match with incorrect domain fails', () async {
      final result = cubit.urlsMatch(
        'https://www.test.com',
        MatchAccuracy.Hostname,
        'https',
        'www.test2.com',
        'test2.com',
      );
      expect(result, false);
    });
    test('minimum domain match with incorrect hostname succeeds', () async {
      final result = cubit.urlsMatch(
        'https://www.test.com',
        MatchAccuracy.Domain,
        'https',
        'www2.test.com',
        'test.com',
      );
      expect(result, true);
    });
    test('mismatched scheme on https page succeeds', () async {
      final result = cubit.urlsMatch('http://www.test.com', MatchAccuracy.Domain, 'https', 'www.test.com', 'test.com');
      expect(result, true);
    });
    test('mismatched scheme on http page fails', () async {
      final result = cubit.urlsMatch('https://www.test.com', MatchAccuracy.Domain, 'http', 'www.test.com', 'test.com');
      expect(result, false);
    });

    test('minimum domain match with port included succeeds', () async {
      final result = cubit.urlsMatch(
        'https://www.test.com:1234',
        MatchAccuracy.Domain,
        'https',
        'www.test.com',
        'test.com',
      );
      expect(result, true);
    });
    test('minimum domain match with IPv4 and port succeeds', () async {
      final result = cubit.urlsMatch('https://1.2.3.4:1234', MatchAccuracy.Domain, 'https', '1.2.3.4', '1.2.3.4');
      expect(result, true);
    });
    test('minimum domain match with IPv6 and port succeeds', () async {
      final result = cubit.urlsMatch(
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
      final result = cubit.urlsMatch(
        'https://www.test.com/path',
        MatchAccuracy.Domain,
        'https',
        'www.test.com',
        'test.com',
      );
      expect(result, true);
    });
    test('minimum hostname match with path and correct hostname succeeds', () async {
      final result = cubit.urlsMatch(
        'https://www.test.com/path',
        MatchAccuracy.Domain,
        'https',
        'www.test.com',
        'test.com',
      );
      expect(result, true);
    });

    test('minimum domain match with private hostname, path and correct hostname succeeds', () async {
      final result = cubit.urlsMatch(
        'https://localmachine/path',
        MatchAccuracy.Domain,
        'https',
        'localmachine',
        'localmachine',
      );
      expect(result, true);
    });
    test('minimum hostname match with private hostname, path and correct hostname succeeds', () async {
      final result = cubit.urlsMatch(
        'https://localmachine/path',
        MatchAccuracy.Hostname,
        'https',
        'localmachine',
        'localmachine',
      );
      expect(result, true);
    });
  });
}
