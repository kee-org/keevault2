import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/autofill_matching.dart';
import 'package:keevault/autofill_save_draft.dart';
import 'package:public_suffix/public_suffix.dart';

AutofillWebDomain dom(String domain, {bool dal = false, bool userSelected = false, bool focused = false}) =>
    AutofillWebDomain(scheme: 'https', domain: domain, dalVerified: dal, userSelected: userSelected, focused: focused);

AutofillMetadata metadata({
  String? appId,
  AppIdSource source = AppIdSource.component,
  bool appIsBrowser = false,
  List<AutofillWebDomain> webDomains = const [],
  String? username = 'alice@example.com',
  String? password = 'correct horse',
}) => AutofillMetadata(
  appId: appId,
  appIdSource: appId == null ? AppIdSource.none : source,
  appIsBrowser: appIsBrowser,
  webDomains: webDomains.toSet(),
  isWebOrigin: webDomains.isNotEmpty,
  saveInfo: SaveInfoMetadata(username: username, password: password),
);

AutofillSaveDraft draftFor(AutofillMetadata m) =>
    AutofillSaveDraft.from(m, AutofillTarget.fromMetadata(m, ownPackageName: 'com.keevault.keevault'));

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  DefaultSuffixRules.initFromString(await rootBundle.loadString('assets/public_suffix_list.dat'));

  group('AutofillSaveDraft', () {
    test('a verified app: the package is linked and the request is trusted', () {
      final d = draftFor(metadata(appId: 'com.example.app'));
      expect(d.androidPackageName, 'com.example.app');
      expect(d.url, isNull);
      expect(d.title, 'com.example.app');
      expect(d.trusted, true);
      expect(d.hasLinks, true);
    });

    test('a verified web domain in a recognised browser: the URL is linked and the app is not', () {
      final d = draftFor(
        metadata(
          appId: 'com.android.chrome',
          appIsBrowser: true,
          webDomains: [dom('login.example.com', dal: true, focused: true)],
        ),
      );
      expect(d.url, 'https://login.example.com');
      expect(d.androidPackageName, isNull);
      expect(d.title, 'login.example.com');
      expect(d.trusted, true);
    });

    test('the scheme defaults to http if Android did not supply one', () {
      final d = draftFor(
        metadata(
          appId: 'com.android.chrome',
          appIsBrowser: true,
          webDomains: [AutofillWebDomain(domain: 'example.com', dalVerified: true, focused: true)],
        ),
      );
      expect(d.url, 'http://example.com');
    });

    test('an unverified web domain: nothing is linked and the request is untrusted', () {
      final d = draftFor(
        metadata(
          appId: 'org.niche.browser',
          appIsBrowser: true,
          webDomains: [dom('example.com', dal: false, focused: true)],
        ),
      );
      expect(d.url, isNull);
      expect(d.androidPackageName, isNull);
      expect(d.hasLinks, false);
      expect(d.trusted, false);
      // The entry can still be saved, with a title that tells the user what asked for it
      expect(d.title, 'example.com');
    });

    test('a verified app showing an unverified website: only the app is linked and the request is untrusted', () {
      final d = draftFor(
        metadata(appId: 'com.example.app', webDomains: [dom('login.microsoftonline.com', focused: true)]),
      );
      expect(d.androidPackageName, 'com.example.app');
      expect(d.url, isNull);
      expect(d.hasLinks, true);
      expect(d.trusted, false);
    });

    test('an app id that the app reported about itself is not linked', () {
      final d = draftFor(metadata(appId: 'com.fake.app', source: AppIdSource.viewNode));
      expect(d.androidPackageName, isNull);
      expect(d.trusted, false);
    });

    test('no identity at all: untrusted with a placeholder title', () {
      final d = draftFor(metadata());
      expect(d.hasLinks, false);
      expect(d.trusted, false);
      expect(d.title, '[untitled]');
    });

    test('a notice about unused web content does not make a verified app untrusted', () {
      // Several domains and none focused, in a verified app
      final d = draftFor(metadata(appId: 'com.example.app', webDomains: [dom('a.com'), dom('b.com')]));
      expect(d.androidPackageName, 'com.example.app');
      expect(d.trusted, true);
    });

    test('username equal to password sets the flag', () {
      final d = draftFor(metadata(appId: 'com.example.app', username: 'secret', password: 'secret'));
      expect(d.sameValue, true);
      // Both are kept. We don't guess which one is wrong.
      expect(d.username, 'secret');
      expect(d.password.getText(), 'secret');
    });

    test('different values or an empty username do not set the flag', () {
      expect(draftFor(metadata(appId: 'com.example.app')).sameValue, false);
      expect(draftFor(metadata(appId: 'com.example.app', username: '', password: '')).sameValue, false);
      expect(draftFor(metadata(appId: 'com.example.app', username: null, password: 'x')).sameValue, false);
    });

    test('the password is a ProtectedValue, even if there is none', () {
      final d = draftFor(metadata(appId: 'com.example.app'));
      expect(d.password, isA<ProtectedValue>());
      expect(d.password.getText(), 'correct horse');

      final empty = draftFor(metadata(appId: 'com.example.app', password: null));
      expect(empty.password, isA<ProtectedValue>());
      expect(empty.password.getText(), '');
    });

    test('a missing username becomes empty text', () {
      expect(draftFor(metadata(appId: 'com.example.app', username: null)).username, '');
    });
  });
}
