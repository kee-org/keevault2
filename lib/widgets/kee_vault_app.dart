import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jiffy/jiffy.dart';
import 'package:keevault/cubit/app_settings_cubit.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/cubit/filter_cubit.dart';
import 'package:keevault/cubit/generator_profiles_cubit.dart';
import 'package:keevault/cubit/sort_cubit.dart';
import 'package:keevault/local_vault_repository.dart';
import 'package:keevault/logging/logger.dart';
import 'package:keevault/credentials/quick_unlocker.dart';
import 'package:keevault/config/environment_config.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
//import 'package:platform/platform.dart';
import '../colors.dart';
import '../config/platform.dart';
import '../cubit/app_rating_cubit.dart';
import '../cubit/interaction_cubit.dart';
import '../remote_vault_repository.dart';
import '../user_repository.dart';
import '../vault_backend/storage_service.dart';
import '../vault_backend/subscription_service.dart';
import '../vault_backend/user.dart';
import '../vault_backend/user_service.dart';
import '../cubit/account_cubit.dart';
import '../cubit/vault_cubit.dart';
import '../generated/l10n.dart';
import 'package:fluro/fluro.dart';
import '../config/app.dart';
import '../config/routes.dart';
import 'package:receive_intent/receive_intent.dart' as ri;

import 'in_app_messenger.dart';

class KeeVaultApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const KeeVaultApp({super.key, required this.navigatorKey});
  @override
  State createState() {
    //TODO:f: Perhaps there is some other place we can assign the AppConfig state
    // rather than in this widget state constructor? Appears to work just fine though.
    // ignore: no_logic_in_create_state
    return KeeVaultAppState(navigatorKey);
  }
}

class KeeVaultAppState extends State<KeeVaultApp> with WidgetsBindingObserver, TraceableClientMixin {
  @override
  String get actionName => widget.toStringShort();

  final entryCubit = EntryCubit();
  final generatorProfilesCubit = GeneratorProfilesCubit();
  final autofillCubit = AutofillCubit();
  late UserRepository userRepo;
  late AccountCubit accountCubit;

  onTokensChange(User user) {
    // A lot of background operations can result in updated information about the
    // user's authentication status or subscription status being changed (via requests
    // like refresh which end up changing the authentication tokens and features
    // available).
    try {
      accountCubit.emitAuthenticatedOrExpiredOrUnvalidated(user);
    } on Exception {
      // blah
    }
  }

  KeeVaultAppState(GlobalKey<NavigatorState> navigatorKey) {
    final router = FluroRouter();
    Routes.configureRoutes(router);
    AppConfig.router = router;
    AppConfig.navigatorKey = navigatorKey;
    userService = UserService(EnvironmentConfig.stage.toStage(), onTokensChange);
    storageService = StorageService(EnvironmentConfig.stage.toStage(), userService.refresh);
    subscriptionService = SubscriptionService(EnvironmentConfig.stage.toStage(), userService.refresh);
    userRepo = UserRepository(userService, subscriptionService, quickUnlocker);
    accountCubit = AccountCubit(userRepo);
  }

  final QuickUnlocker quickUnlocker = QuickUnlocker();
  late UserService userService;
  late StorageService storageService;
  late SubscriptionService subscriptionService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async => await Jiffy.setLocale('en_gb'));
    WidgetsBinding.instance.addObserver(this);
    if (KeeVaultPlatform.isAndroid) _initReceiveIntentSubscription();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (KeeVaultPlatform.isAndroid) unawaited(_receiveIntentSubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    l.t('App State: $state');
  }

  StreamSubscription? _receiveIntentSubscription;

  void _initReceiveIntentSubscription() async {
    _receiveIntentSubscription = ri.ReceiveIntent.receivedIntentStream.listen((ri.Intent? intent) {
      l.d('Received intent: $intent');
      final navigator = widget.navigatorKey.currentState;
      final navContext = navigator?.overlay?.context;
      if (navContext == null) {
        l.e('Nav context unexpectedly missing. Autofill navigation is likely to fail in strange ways.');
        return;
      }
      final mode = intent?.extra?['autofill_mode'];
      if (mode?.startsWith('/autofill') ?? false) {
        BlocProvider.of<AutofillCubit>(navContext).refresh();
      }
    }, onError: (err) {
      l.e('intent error: $err');
    });
  }

  ThemeData getThemeData(bool isDark, MaterialColor palette) {
    final theme = isDark
        ? ThemeData.from(
            useMaterial3: false,
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: palette,
              brightness: Brightness.dark,
              cardColor: Color(0xFF292929),
              accentColor: AppPalettes.keeVaultPaletteAccent[100],
              backgroundColor: Colors.grey[900],
            ).copyWith(
              surface: Colors.grey[850],
              secondaryContainer: palette[700],
            ),
          )
        : ThemeData.from(
            useMaterial3: false,
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: palette,
              brightness: Brightness.light,
              cardColor: Colors.white,
              accentColor: palette[500],
              backgroundColor: Colors.grey[50],
            ).copyWith(
              surface: Colors.grey[100],
              secondaryContainer: palette[700],
            ),
          );
    return theme.copyWith(
      primaryColor: palette[500],
      canvasColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBarTheme: theme.appBarTheme.copyWith(backgroundColor: palette[500]),
      textSelectionTheme: TextSelectionThemeData(
        selectionHandleColor: palette[500],
        cursorColor: isDark ? palette[50] : palette[500],
        selectionColor: isDark ? palette[700] : palette[100],
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: isDark ? palette[100] : palette[600])),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: theme.colorScheme.secondary)),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return theme.colorScheme.secondary;
          }
          return null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return theme.colorScheme.secondary;
          }
          return null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return theme.colorScheme.secondary;
          }
          return null;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return theme.colorScheme.secondary;
          }
          return null;
        }),
      ),
      bottomAppBarTheme: BottomAppBarTheme(color: isDark ? palette[800] : palette[100]),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          errorStyle: theme.inputDecorationTheme.errorStyle?.copyWith(fontWeight: FontWeight.bold) ??
              TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    const palette = AppPalettes.keeVaultPalette;
    return BlocProvider(
      create: (context) => AppSettingsCubit(),
      child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
        builder: (context, appSettingsState) {
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                  create: (context) => VaultCubit(
                        userRepo,
                        quickUnlocker,
                        RemoteVaultRepository(userService, storageService),
                        LocalVaultRepository(quickUnlocker),
                        entryCubit,
                        autofillCubit.isAutofilling,
                        generatorProfilesCubit,
                        accountCubit,
                      )),
              BlocProvider(create: (context) => accountCubit),
              BlocProvider(create: (context) => entryCubit),
              BlocProvider(create: (context) => FilterCubit()),
              BlocProvider(create: (context) => SortCubit()),
              BlocProvider(create: (context) => autofillCubit),
              BlocProvider(create: (context) => generatorProfilesCubit),
              BlocProvider(create: (context) => InteractionCubit()),
              BlocProvider(create: (context) => AppRatingCubit()),
            ],
            child: InAppMessengerWidget(
              appSettingsState: appSettingsState,
              navigatorKey: widget.navigatorKey,
              child: GestureDetector(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  localizationsDelegates: const [
                    S.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  navigatorKey: widget.navigatorKey,
                  supportedLocales: S.delegate.supportedLocales,
                  title: 'Kee Vault',
                  theme: getThemeData(false, palette),
                  darkTheme: getThemeData(true, palette),
                  themeMode: (appSettingsState as AppSettingsBasic).themeMode,
                  onGenerateRoute: AppConfig.router.generator,
                  initialRoute: '/',
                  navigatorObservers: [
                    matomoObserver,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
