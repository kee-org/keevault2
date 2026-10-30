import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/cubit/account_cubit.dart';
import 'package:keevault/cubit/autocomplete_cubit.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/cubit/filter_cubit.dart';
import 'package:keevault/cubit/generator_profiles_cubit.dart';
import 'package:keevault/cubit/vault_cubit.dart';
import 'package:keevault/generated/l10n.dart';
import 'package:keevault/local_vault_repository.dart';
import 'package:keevault/locked_vault_file.dart';
import 'package:keevault/remote_vault_repository.dart';
import 'package:keevault/credentials/quick_unlocker.dart';
import 'package:keevault/user_repository.dart';
import 'package:keevault/vault_backend/user.dart';
import 'package:keevault/vault_file.dart';
import 'package:keevault/widgets/autofill_save.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:public_suffix/public_suffix.dart';

class _FakeUserRepository extends Fake implements UserRepository {}

class _FakeQuickUnlocker extends Fake implements QuickUnlocker {}

class _FakeRemoteVaultRepository extends Fake implements RemoteVaultRepository {}

class _FakeLocalVaultRepository extends Fake implements LocalVaultRepository {}

class _FakeGeneratorProfilesCubit extends Fake implements GeneratorProfilesCubit {}

/// Records saves instead of touching the disk or network
class _TestVaultCubit extends VaultCubit {
  int saveCount = 0;
  List<String> titlesAtSave = [];

  _TestVaultCubit(
    LocalVaultFile vault,
    EntryCubit entryCubit,
    AccountCubit accountCubit,
    AutocompleteCubit autocomplete,
  ) : super(
        _FakeUserRepository(),
        _FakeQuickUnlocker(),
        _FakeRemoteVaultRepository(),
        _FakeLocalVaultRepository(),
        entryCubit,
        () => false,
        _FakeGeneratorProfilesCubit(),
        accountCubit,
        autocomplete,
      ) {
    emit(VaultLoaded(vault));
  }

  @override
  Future<void> save(User? user, {bool skipRemote = false}) async {
    saveCount++;
    titlesAtSave = currentVaultFile!.files.current.body.rootGroup
        .getAllEntries(enterRecycleBin: false)
        .values
        .map((e) => e.getString(KdbxKeyCommon.TITLE)?.getText() ?? '')
        .toList();
  }
}

/// Does what the real one does except talk to the platform
class _TestAutofillCubit extends AutofillCubit {
  int finished = 0;
  int abandoned = 0;

  _TestAutofillCubit() {
    ownPackageNameForTesting = 'com.keevault.keevault';
  }

  int _requestId = 0;

  void startRequest(AutofillMetadata metadata) => emit(AutofillSaving(metadata, requestId: ++_requestId));

  @override
  Future<void> finishSaving() async {
    finished++;
    emit(AutofillAvailable(true));
  }

  @override
  Future<void> abandonSaving() async {
    abandoned++;
    emit(AutofillAvailable(true));
  }
}

/// A verified native app, so the request is trusted
AutofillMetadata trustedApp({String username = 'alice@example.com', String password = 'hunter2-correct-horse'}) =>
    AutofillMetadata(
      appId: 'com.example.app',
      appIdSource: AppIdSource.component,
      webDomains: {},
      saveInfo: SaveInfoMetadata(username: username, password: password),
    );

/// A browser we do not recognise, so the request is untrusted and nothing can be linked
AutofillMetadata untrustedBrowser({String username = 'bob@example.org', String password = 'other-secret-value'}) =>
    AutofillMetadata(
      appId: 'org.niche.browser',
      appIdSource: AppIdSource.component,
      appIsBrowser: true,
      webDomains: {AutofillWebDomain(scheme: 'https', domain: 'example.org', focused: true)},
      isWebOrigin: true,
      saveInfo: SaveInfoMetadata(username: username, password: password),
    );

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  DefaultSuffixRules.initFromString(await rootBundle.loadString('assets/public_suffix_list.dat'));

  // The screen reports its views to Matomo. Opted out so that nothing is ever sent.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await MatomoTracker.instance.initialize(
      siteId: '1',
      url: 'https://matomo.invalid/js/',
      optOut: true,
      pingInterval: null,
      userAgent: 'test',
      packageInfo: PackageInfo(appName: 'test', packageName: 'test', version: '1', buildNumber: '1'),
    );
  });

  late KdbxFile file;
  late EntryCubit entryCubit;
  late _TestAutofillCubit autofillCubit;
  late _TestVaultCubit vaultCubit;

  Iterable<KdbxEntry> entries() => file.body.rootGroup.getAllEntries(enterRecycleBin: false).values;

  KdbxEntry onlyEntry() => entries().single;

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    file = KdbxFormat().create(Credentials(ProtectedValue.fromString('test')), 'test');
    entryCubit = EntryCubit();
    final accountCubit = AccountCubit(_FakeUserRepository());
    final autocompleteCubit = AutocompleteCubit();
    // Started when the vault was opened
    final filterCubit = FilterCubit()..start(file.body.rootGroup.uuid.uuid, true);
    autofillCubit = _TestAutofillCubit();
    vaultCubit = _TestVaultCubit(
      LocalVaultFile(
        VaultFileVersions(
          current: file,
          remoteMergeTargetLocked: LockedVaultFile(Uint8List(0), DateTime.now(), null, null, null),
        ),
        DateTime.now(),
        DateTime.now(),
        'uuid',
        null,
        null,
      ),
      entryCubit,
      accountCubit,
      autocompleteCubit,
    );
    addTearDown(() async {
      await autofillCubit.close();
      await vaultCubit.close();
      await entryCubit.close();
      await accountCubit.close();
      await autocompleteCubit.close();
      await filterCubit.close();
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<VaultCubit>.value(value: vaultCubit),
          BlocProvider<EntryCubit>.value(value: entryCubit),
          BlocProvider<AccountCubit>.value(value: accountCubit),
          BlocProvider<AutofillCubit>.value(value: autofillCubit),
          BlocProvider<AutocompleteCubit>.value(value: autocompleteCubit),
          BlocProvider<FilterCubit>.value(value: filterCubit),
        ],
        child: MaterialApp(
          localizationsDelegates: const [S.delegate, ...GlobalMaterialLocalizations.delegates],
          supportedLocales: S.delegate.supportedLocales,
          // Like VaultWidget: a keyed save screen while saving, anything else when not
          home: BlocBuilder<AutofillCubit, AutofillState>(
            builder: (context, state) => state is AutofillSaving
                ? AutofillSaveWidget(key: ValueKey(state.requestId))
                : const Scaffold(body: Text('vault list')),
          ),
        ),
      ),
    );
  }

  Future<void> startRequest(WidgetTester tester, AutofillMetadata metadata) async {
    autofillCubit.startRequest(metadata);
    await tester.pumpAndSettle();
  }

  testWidgets('untrusted request, Save without any edits: the entry is added and saved', (tester) async {
    await pumpScreen(tester);
    await startRequest(tester, untrustedBrowser());

    // Nothing in the vault until the user chooses to save
    expect(entries(), isEmpty);

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final entry = onlyEntry();
    expect(entry.getString(KdbxKeyCommon.USER_NAME)?.getText(), 'bob@example.org');
    expect(entry.getString(KdbxKeyCommon.PASSWORD), isA<ProtectedValue>());
    expect(entry.getString(KdbxKeyCommon.PASSWORD)?.getText(), 'other-secret-value');
    expect(entry.getString(KdbxKeyCommon.URL)?.getText() ?? '', isEmpty);
    expect(entry.androidPackageNames, isEmpty);
    expect(vaultCubit.saveCount, 1);
    expect(vaultCubit.titlesAtSave, ['example.org']);
    expect(autofillCubit.finished, 1);
    expect(autofillCubit.abandoned, 0);
    expect(find.text('vault list'), findsOneWidget);
  });

  testWidgets('trusted request: what Android verified is linked', (tester) async {
    await pumpScreen(tester);
    await startRequest(tester, trustedApp());
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final entry = onlyEntry();
    expect(entry.androidPackageNames, ['com.example.app']);
    expect(entry.getString(KdbxKeyCommon.TITLE)?.getText(), 'com.example.app');
    expect(entry.getString(KdbxKeyCommon.PASSWORD), isA<ProtectedValue>());
    expect(vaultCubit.saveCount, 1);
    expect(autofillCubit.finished, 1);
  });

  testWidgets('verified website in a recognised browser: the URL is linked', (tester) async {
    await pumpScreen(tester);
    await startRequest(
      tester,
      AutofillMetadata(
        appId: 'com.android.chrome',
        appIdSource: AppIdSource.component,
        appIsBrowser: true,
        webDomains: {AutofillWebDomain(scheme: 'https', domain: 'login.example.com', dalVerified: true, focused: true)},
        isWebOrigin: true,
        saveInfo: SaveInfoMetadata(username: 'carol', password: 'carols-password'),
      ),
    );
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final entry = onlyEntry();
    expect(entry.getString(KdbxKeyCommon.URL)?.getText(), 'https://login.example.com');
    expect(entry.androidPackageNames, isEmpty);
    expect(entry.getString(KdbxKeyCommon.TITLE)?.getText(), 'login.example.com');
  });

  testWidgets('the header says nothing is saved yet and untrusted requests are explained inline, with no dialog', (
    tester,
  ) async {
    await pumpScreen(tester);
    await startRequest(tester, untrustedBrowser());

    expect(find.textContaining('has not been saved'), findsOneWidget);
    expect(find.textContaining('could not verify the app or website'), findsOneWidget);
    // The concern banner from the target, described for saving rather than filling
    expect(find.textContaining("This browser isn't one we recognise"), findsOneWidget);
    expect(find.textContaining("The new entry won't be linked to"), findsOneWidget);
    expect(find.textContaining('before filling'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Not trusted'), findsNothing);
  });

  testWidgets('trusted header has no warnings', (tester) async {
    await pumpScreen(tester);
    await startRequest(tester, trustedApp());

    expect(find.textContaining('then tap Save to add it to your vault'), findsOneWidget);
    expect(find.textContaining('could not verify'), findsNothing);
  });

  testWidgets('the password is obscured and the username is not', (tester) async {
    await pumpScreen(tester);
    await startRequest(tester, trustedApp());

    expect(find.text('alice@example.com'), findsOneWidget);
    expect(find.text('hunter2-correct-horse'), findsNothing);
  });

  testWidgets('the same value for username and password shows a notice and keeps both', (tester) async {
    await pumpScreen(tester);
    await startRequest(tester, trustedApp(username: 'dup-value', password: 'dup-value'));

    expect(find.textContaining('same value for the username and password'), findsOneWidget);
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(onlyEntry().getString(KdbxKeyCommon.USER_NAME)?.getText(), 'dup-value');
    expect(onlyEntry().getString(KdbxKeyCommon.PASSWORD)?.getText(), 'dup-value');
  });

  for (final trusted in [true, false]) {
    final name = trusted ? 'trusted' : 'untrusted';

    testWidgets('$name request, system back then Discard: nothing is added or saved and autofill mode ends', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startRequest(tester, trusted ? trustedApp() : untrustedBrowser());

      // No edits have been made but the user is still asked
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Do you want to save this new entry?'), findsOneWidget);

      await tester.tap(find.text('DISCARD'));
      await tester.pumpAndSettle();

      expect(entries(), isEmpty);
      expect(vaultCubit.saveCount, 0);
      expect(autofillCubit.abandoned, 1);
      expect(autofillCubit.finished, 0);
      expect(autofillCubit.state, isA<AutofillAvailable>());
      expect(autofillCubit.state, isNot(isA<AutofillSaving>()));
      expect(entryCubit.state, isA<EntryInitial>());
      expect(find.text('vault list'), findsOneWidget);
    });
  }

  testWidgets('the app bar back button asks too, and Save from the prompt saves', (tester) async {
    await pumpScreen(tester);
    await startRequest(tester, trustedApp());

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Do you want to save this new entry?'), findsOneWidget);
    expect(entries(), isEmpty);

    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('SAVE')));
    await tester.pumpAndSettle();

    expect(entries().length, 1);
    expect(vaultCubit.saveCount, 1);
    expect(autofillCubit.finished, 1);
  });

  testWidgets('a second request gets a new screen with its own values', (tester) async {
    await pumpScreen(tester);
    await startRequest(tester, trustedApp(username: 'first-user', password: 'first-secret'));
    expect(find.text('first-user'), findsOneWidget);

    // Never saved or discarded: another request arrives while this one is still showing
    await startRequest(tester, untrustedBrowser(username: 'second-user', password: 'second-secret'));

    expect(find.text('first-user'), findsNothing);
    expect(find.text('second-user'), findsOneWidget);
    expect(find.textContaining('could not verify the app or website'), findsOneWidget);
    // The first request left nothing behind
    expect(entries(), isEmpty);

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    final entry = onlyEntry();
    expect(entry.getString(KdbxKeyCommon.USER_NAME)?.getText(), 'second-user');
    expect(entry.getString(KdbxKeyCommon.PASSWORD)?.getText(), 'second-secret');
    expect(entry.androidPackageNames, isEmpty);
  });
}
