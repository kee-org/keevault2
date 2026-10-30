import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/autofill_matching.dart';
import 'package:keevault/generated/l10n.dart';
import 'package:keevault/widgets/autofill_target_card.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late S str;

  setUpAll(() async {
    str = await S.load(const Locale('en'));
  });

  final web = WebSignal(AutofillWebDomain(scheme: 'https', domain: 'login.example.com'), SignalTrust.unverified);
  const verifiedApp = AppSignal('com.example.app', SignalTrust.verified, AppIdSource.component);

  // Targets shaped like the ones AutofillTarget.fromMetadata produces for each concern
  AutofillTarget targetFor(AutofillConcern concern) => switch (concern) {
    AutofillConcern.domainNotOwnedByApp => AutofillTarget(
      app: verifiedApp,
      web: web,
      contextAppId: 'com.example.app',
      contextAppIdTrusted: true,
      concerns: {concern},
    ),
    AutofillConcern.focusedDomainUnknown => AutofillTarget(
      app: verifiedApp,
      contextAppId: 'com.example.app',
      contextAppIdTrusted: true,
      concerns: {concern},
    ),
    _ => AutofillTarget(web: web, contextAppId: 'com.example.app', concerns: {concern}),
  };

  // Phrases that only make sense when filling: there is no entry list, match badge or form to fill when saving
  const fillOnlyPhrases = ['filling', 'filled', 'matches', 'Unverified', 'entries'];

  for (final concern in AutofillConcern.values) {
    test('${concern.name}: the save message does not describe filling', () {
      final message = autofillSaveConcernMessage(str, concern, targetFor(concern));
      expect(message, isNotEmpty);
      for (final phrase in fillOnlyPhrases) {
        expect(message, isNot(contains(phrase)), reason: '"$message" mentions "$phrase"');
      }
      expect(message, contains('new entry'));
    });
  }

  test('focusedDomainUnknown in a verified app says the entry is linked to the app only', () {
    expect(
      autofillSaveConcernMessage(
        str,
        AutofillConcern.focusedDomainUnknown,
        targetFor(AutofillConcern.focusedDomainUnknown),
      ),
      str.autofillSaveWarningFocusedDomainUnknownApp,
    );
    expect(
      autofillSaveConcernMessage(
        str,
        AutofillConcern.focusedDomainUnknown,
        const AutofillTarget(concerns: {AutofillConcern.focusedDomainUnknown}),
      ),
      str.autofillSaveWarningFocusedDomainUnknown,
    );
  });

  test('a domain concern names the domain that will not be linked', () {
    expect(
      autofillSaveConcernMessage(
        str,
        AutofillConcern.unrecognisedBrowser,
        targetFor(AutofillConcern.unrecognisedBrowser),
      ),
      contains("won't be linked to login.example.com"),
    );
  });
}
