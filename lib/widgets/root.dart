import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/widgets/account_wrapper.dart';
import 'package:keevault/widgets/bottom.dart';
import '../cubit/account_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/vault_cubit.dart';

class RootWidget extends StatefulWidget {
  const RootWidget({Key? key}) : super(key: key);

  @override
  RootWidgetState createState() => RootWidgetState();
}

class RootWidgetState extends State<RootWidget> {
  @override
  void initState() {
    super.initState();
    _updateStatus();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> _updateStatus() async {
    setState(() {});
    await _startup();
  }

  // Cubit startup functions are idempotent
  Future<void> _startup() async {
    final accountCubit = BlocProvider.of<AccountCubit>(context);
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    await BlocProvider.of<AutofillCubit>(context).refresh();
    await accountCubit.startup();
    final AccountState state = accountCubit.state;
    if (state is AccountChosen) {
      await vaultCubit.startup(state.user, null);
    } else if (state is AccountLocalOnly) {
      await vaultCubit.startupFreeMode(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image(
          image: AssetImage('assets/vault.png'),
          excludeFromSemantics: true,
          height: 48,
          color: Colors.white,
        ),
        centerTitle: true,
        toolbarHeight: 80,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const <Widget>[
              AccountWrapperWidget(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomBarWidget(() => toggleBottomDrawerVisibility(context)),
    );
  }
}
