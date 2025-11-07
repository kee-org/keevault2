import 'package:flutter/gestures.dart';
import 'package:keevault/vault_file.dart';
import 'package:keevault/widgets/dialog_utils.dart';
import '../cubit/account_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/vault_cubit.dart';
import '../generated/l10n.dart';

class VaultImportedWidget extends StatelessWidget {
  const VaultImportedWidget({super.key});

  Future<void> _loadVault(LocalVaultFile vault, BuildContext context) async {
    final accountCubit = BlocProvider.of<AccountCubit>(context);
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    await vaultCubit.emitVaultLoaded(
      vault,
      accountCubit.currentUserIfKnown,
      safe: false,
      immediateRemoteRefresh: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VaultCubit, VaultState>(
      builder: (context, state) {
        final theme = Theme.of(context);
        final str = S.of(context);
        final vaultState = state as VaultImported;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
              child: Text(str.importComplete, style: theme.textTheme.headlineSmall),
            ),
            ...(vaultState.manual ? _manual(str, theme) : _free(str, theme)),
            FilledButton(
              onPressed: () => {_loadVault(vaultState.vault, context)},
              child: Text(str.importedContinueToVault),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _free(S str, ThemeData theme) {
    return [
      Padding(padding: const EdgeInsets.only(top: 16.0, right: 16.0, left: 16.0), child: Text(str.importedFree1)),
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium,
            children: <TextSpan>[
              TextSpan(text: str.importedFree2, style: theme.textTheme.bodyMedium),
              TextSpan(
                text: str.thisCommunityForumTopic,
                style: theme.textTheme.bodyMedium!.copyWith(
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w900,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () async {
                    await DialogUtils.openUrl('https://forum.kee.pm/t/kee-vault-2-imported-entries/3852');
                  },
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _manual(S str, ThemeData theme) {
    return [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium,
            children: <TextSpan>[
              TextSpan(text: str.importedManual, style: theme.textTheme.bodyMedium),
              TextSpan(
                text: str.thisCommunityForumTopic,
                style: theme.textTheme.bodyMedium!.copyWith(
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w900,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () async {
                    await DialogUtils.openUrl('https://forum.kee.pm/t/kee-vault-2-imported-entries/3852');
                  },
              ),
            ],
          ),
        ),
      ),
    ];
  }
}
