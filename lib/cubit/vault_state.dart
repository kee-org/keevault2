part of 'vault_cubit.dart';

@immutable
abstract class VaultState {
  const VaultState();
}

class VaultInitial extends VaultState {
  const VaultInitial();
}

class VaultDownloading extends VaultState {
  const VaultDownloading();
}

class VaultDownloadCredentialsRequired extends VaultState {
  final String reason;
  final bool causedByInteraction;
  const VaultDownloadCredentialsRequired(this.reason, this.causedByInteraction);
}

// Refresh can only be started when state is Loaded; maybe later also VaultUpdatingLocalFromRemote
// if we want to download multiple remote updates before merging the first one has completed
class VaultRefreshing extends VaultLoaded {
  const VaultRefreshing(LocalVaultFile vault) : super(vault);
}

class VaultUpdatingLocalFromRemote extends VaultRefreshing {
  const VaultUpdatingLocalFromRemote(LocalVaultFile vault) : super(vault);
}

class VaultRefreshCredentialsRequired extends VaultLoaded {
  final String reason;
  final bool causedByInteraction;
  const VaultRefreshCredentialsRequired(LocalVaultFile vault, this.reason, this.causedByInteraction) : super(vault);
}

class VaultCreating extends VaultState {
  const VaultCreating();
}

class VaultOpening extends VaultState {
  const VaultOpening();
}

class VaultImporting extends VaultOpening {
  const VaultImporting();
}

class VaultLocalFileCredentialsRequired extends VaultState {
  final String reason;
  final bool causedByInteraction;
  final QUStatus quStatus;
  const VaultLocalFileCredentialsRequired(this.reason, this.causedByInteraction, {this.quStatus = QUStatus.unknown});
}

class VaultRemoteFileCredentialsRequired extends VaultState {
  final LocalVaultFile vaultLocal;
  final bool causedByInteraction;
  const VaultRemoteFileCredentialsRequired(this.vaultLocal, this.causedByInteraction);
}

class VaultImportingCredentialsRequired extends VaultState {
  final LocalVaultFile destination;
  final LockedVaultFile source;
  final bool causedByInteraction;
  final bool manual;
  const VaultImportingCredentialsRequired(this.destination, this.source, this.causedByInteraction, this.manual);
}

class VaultImported extends VaultState {
  final LocalVaultFile vault;
  final bool manual;
  const VaultImported(this.vault, this.manual);
}

class VaultLoaded extends VaultState {
  final LocalVaultFile vault;
  const VaultLoaded(this.vault);
}

class VaultError extends VaultState {
  final String message;
  const VaultError(this.message);
}

class VaultBackgroundError extends VaultLoaded {
  final String message;
  final bool toast;
  const VaultBackgroundError(LocalVaultFile vault, this.message, this.toast) : super(vault);
}

class VaultSaving extends VaultLoaded {
  final bool locally;
  final bool remotely;
  const VaultSaving(LocalVaultFile vault, this.locally, this.remotely) : super(vault);
}

class VaultReconcilingUpload extends VaultSaving {
  const VaultReconcilingUpload(LocalVaultFile vault, bool locally, bool remotely) : super(vault, locally, remotely);
}

class VaultUploadCredentialsRequired extends VaultReconcilingUpload {
  final bool causedByInteraction;
  const VaultUploadCredentialsRequired(LocalVaultFile vault, bool locally, bool remotely, this.causedByInteraction)
      : super(vault, locally, remotely);
}
