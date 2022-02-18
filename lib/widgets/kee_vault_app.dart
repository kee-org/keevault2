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
import 'package:keevault/quick_unlocker.dart';
import 'package:keevault/config/environment_config.dart';
import 'package:matomo/matomo.dart';
import '../colors.dart';
import '../remote_vault_repository.dart';
import '../user_repository.dart';
import '../vault_backend/storage_service.dart';
import '../vault_backend/user_service.dart';
import '../cubit/account_cubit.dart';
import '../cubit/vault_cubit.dart';
import '../generated/l10n.dart';
import 'package:fluro/fluro.dart';
import '../config/app.dart';
import '../config/routes.dart';
import 'package:receive_intent/receive_intent.dart' as ri;

class KeeVaultApp extends TraceableStatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const KeeVaultApp({Key? key, required this.navigatorKey}) : super(key: key);
  @override
  State createState() {
    return KeeVaultAppState();
  }
}

class KeeVaultAppState extends State<KeeVaultApp> with WidgetsBindingObserver {
  KeeVaultAppState() {
    final router = FluroRouter();
    Routes.configureRoutes(router);
    AppConfig.router = router;
    userService = UserService(EnvironmentConfig.stage.toStage(), null);
    storageService = StorageService(EnvironmentConfig.stage.toStage(), userService.refresh);
  }

  final QuickUnlocker quickUnlocker = QuickUnlocker();
  late UserService userService;
  late StorageService storageService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) => Jiffy.locale('en_gb'));
    WidgetsBinding.instance!.addObserver(this);
    _initReceiveIntentSubscription();
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    _receiveIntentSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    l.v('App State: $state');
  }

  StreamSubscription? _receiveIntentSubscription;

  Future<void> _initReceiveIntentSubscription() async {
    _receiveIntentSubscription = ri.ReceiveIntent.receivedIntentStream.listen((ri.Intent? intent) {
      l.w('Received intent: $intent');
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
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: palette,
              brightness: Brightness.dark,
              cardColor: Color(0xFF292929),
              accentColor: AppPalettes.keeVaultPaletteAccent[100],
              backgroundColor: Colors.grey[900],
              primaryColorDark: palette[700],
            ).copyWith(
              surface: Colors.grey[850],
              secondaryVariant: palette[700],
            ),
          )
        : ThemeData.from(
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: palette,
              brightness: Brightness.light,
              cardColor: Colors.white,
              accentColor: palette[500],
              backgroundColor: Colors.grey[50],
              primaryColorDark: palette[700],
            ).copyWith(
              surface: Colors.grey[100],
              secondaryVariant: palette[700],
            ),
          );
    return theme.copyWith(
      primaryColor: palette[500],
      toggleableActiveColor: theme.colorScheme.secondary,
      canvasColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBarTheme: theme.appBarTheme.copyWith(backgroundColor: palette[500]),
      bottomAppBarColor: isDark ? palette[800] : palette[100],
      textSelectionTheme: TextSelectionThemeData(
        selectionHandleColor: palette[500],
        cursorColor: palette[500],
        selectionColor: isDark ? palette[700] : palette[100],
      ),
      outlinedButtonTheme:
          OutlinedButtonThemeData(style: OutlinedButton.styleFrom(primary: isDark ? palette[100] : palette[600])),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(primary: theme.colorScheme.secondary)),
    );
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final entryCubit = EntryCubit();
    final generatorProfilesCubit = GeneratorProfilesCubit();
    final autofillCubit = AutofillCubit();
    const palette = AppPalettes.keeVaultPalette;
    final userRepo = UserRepository(userService, quickUnlocker);
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
                      )),
              BlocProvider(create: (context) => AccountCubit(userRepo)),
              BlocProvider(create: (context) => entryCubit),
              BlocProvider(create: (context) => FilterCubit()),
              BlocProvider(create: (context) => SortCubit()),
              BlocProvider(create: (context) => autofillCubit),
              BlocProvider(create: (context) => generatorProfilesCubit),
            ],
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
            ),
          );
        },
      ),
    );
  }
}
