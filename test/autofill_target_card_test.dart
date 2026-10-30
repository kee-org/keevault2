import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/autofill_matching.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/generated/l10n.dart';
import 'package:keevault/widgets/autofill_target_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:public_suffix/public_suffix.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  DefaultSuffixRules.initFromString(await rootBundle.loadString('assets/public_suffix_list.dat'));

  Future<void> pumpCard(WidgetTester tester, AutofillMetadata metadata) async {
    final target = AutofillTarget.fromMetadata(metadata, ownPackageName: 'com.keevault.keevault');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: S.delegate.supportedLocales,
        home: BlocProvider(
          create: (_) => AutofillCubit(),
          child: Scaffold(
            body: SingleChildScrollView(child: AutofillTargetCard(state: AutofillRequested(target, metadata))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the other domains on the page, which will not be filled', (tester) async {
    await pumpCard(
      tester,
      AutofillMetadata(
        appId: 'com.android.chrome',
        appIdSource: AppIdSource.component,
        appIsBrowser: true,
        webDomains: {
          AutofillWebDomain(domain: 'shop.com', dalVerified: true),
          AutofillWebDomain(domain: 'login.idp.com', dalVerified: true, focused: true),
        },
        isWebOrigin: true,
        saveInfo: null,
      ),
    );
    expect(find.text('login.idp.com'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('in com.android.chrome'), findsOneWidget);
    expect(find.text("On a page that also shows shop.com (these won't be filled)"), findsOneWidget);
  });

  testWidgets('a link-setting-only domain gets its own chip', (tester) async {
    await pumpCard(
      tester,
      AutofillMetadata(
        appId: 'com.example.app',
        appIdSource: AppIdSource.component,
        webDomains: {AutofillWebDomain(domain: 'example.com', userSelected: true, focused: true)},
        isWebOrigin: true,
        saveInfo: null,
      ),
    );
    expect(find.text('Link setting only'), findsOneWidget);
    expect(find.text('Also link example.com'), findsOneWidget);
  });

  testWidgets('a self-reported browser id is shown as a claim', (tester) async {
    await pumpCard(
      tester,
      AutofillMetadata(
        appId: 'com.android.chrome',
        appIdSource: AppIdSource.viewNode,
        appIsBrowser: true,
        webDomains: {AutofillWebDomain(domain: 'bank.com', focused: true)},
        isWebOrigin: true,
        saveInfo: null,
      ),
    );
    expect(find.text("Can't check"), findsOneWidget);
    expect(find.text('in an app that says it is com.android.chrome'), findsOneWidget);
  });
}
