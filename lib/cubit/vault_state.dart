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

// Refresh can only be started when state is Loaded
class VaultRefreshing extends VaultLoaded {
  const VaultRefreshing(super.vault);
}

class VaultUpdatingLocalFromRemote extends VaultRefreshing {
  const VaultUpdatingLocalFromRemote(super.vault);
}

class VaultUpdatingLocalFromAutofill extends VaultRefreshing {
  const VaultUpdatingLocalFromAutofill(super.vault);
}

class VaultRefreshCredentialsRequired extends VaultLoaded {
  final String reason;
  final bool causedByInteraction;
  final PasswordMismatchRecoverySituation recovery;
  const VaultRefreshCredentialsRequired(super.vault, this.reason, this.causedByInteraction, this.recovery);
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
  const VaultBackgroundError(super.vault, this.message, this.toast);
}

class VaultSaving extends VaultLoaded {
  final bool locally;
  final bool remotely;
  const VaultSaving(super.vault, this.locally, this.remotely);
}

class VaultReconcilingUpload extends VaultSaving {
  const VaultReconcilingUpload(super.vault, super.locally, super.remotely);
}

class VaultUploadCredentialsRequired extends VaultReconcilingUpload {
  final bool causedByInteraction;
  final PasswordMismatchRecoverySituation recovery;
  const VaultUploadCredentialsRequired(
    super.vault,
    super.locally,
    super.remotely,
    this.causedByInteraction,
    this.recovery,
  );
}

class VaultChangingPassword extends VaultLoaded {
  final String? error;
  const VaultChangingPassword(super.vault, this.error);
}
