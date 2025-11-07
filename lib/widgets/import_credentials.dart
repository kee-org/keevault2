import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/vault_cubit.dart';
import '../vault_file.dart';
import 'vault_password_credentials.dart';
import '../generated/l10n.dart';

class ImportCredentialsWidget extends StatelessWidget {
  const ImportCredentialsWidget({super.key, required this.submitPassword, required this.vaultState});

  final Future<void> Function(String) submitPassword;
  final VaultImportingCredentialsRequired vaultState;

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        VaultPasswordCredentialsWidget(
          reason: str.importUnlockRequired,
          onSubmit: submitPassword,
          showError: vaultState.causedByInteraction,
        ),
        vaultState.manual
            ? FilledButton(
                onPressed: () => {_cancelImport(context, vaultState.destination)},
                style: FilledButton.styleFrom(backgroundColor: theme.buttonTheme.colorScheme!.error),
                child: Text('Cancel import'),
              )
            : Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                      border: Border.all(color: theme.colorScheme.primary, width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            "Can't remember your password? It's better if you try some other possibilities first but if you want to give up now, there is an escape hatch!",
                            textAlign: TextAlign.left,
                            style: theme.textTheme.titleMedium?.copyWith(
                              height: 1.4,
                              fontSize: (theme.textTheme.titleMedium!.fontSize ?? 14) - 3,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Your old data will remain available on this device only, for the next 90 days. You can export it to a file using the "Import/Export" screen.',
                            textAlign: TextAlign.left,
                            style: theme.textTheme.titleMedium?.copyWith(
                              height: 1.4,
                              fontSize: (theme.textTheme.titleMedium!.fontSize ?? 14) - 3,
                            ),
                          ),
                        ),
                        OverflowBar(
                          alignment: MainAxisAlignment.end,
                          children: [
                            FilledButton(
                              onPressed: () => {_skipImport(context, vaultState.destination)},
                              style: FilledButton.styleFrom(backgroundColor: theme.buttonTheme.colorScheme!.error),
                              child: Text('Skip import'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Future<void> _skipImport(BuildContext context, LocalVaultFile destination) async {
    await BlocProvider.of<VaultCubit>(context).skipLocalFreeKdbxImport(destination);
  }

  Future<void> _cancelImport(BuildContext context, LocalVaultFile destination) async {
    await BlocProvider.of<VaultCubit>(context).emitVaultLoaded(destination, null, safe: false);
  }
}
