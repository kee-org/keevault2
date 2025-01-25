part of 'account_cubit.dart';

@immutable
abstract class AccountState {
  const AccountState();
}

class AccountInitial extends AccountState {}

class AccountLocalOnlyRequested extends AccountState {}

class AccountLocalOnly extends AccountState {}

class AccountUnknown extends AccountState {}

class AccountChosen extends AccountState {
  final User user;
  const AccountChosen(this.user);
}

class AccountIdentifying extends AccountChosen {
  const AccountIdentifying(super.user);
}

// Being Identified means either the remote service was unavailable or it accepted the email address (which
// it typically does for every submission). Thus, there are very limited circumstances where an
// AccountChosen status is unable to progress to AccountIdentified and it is critical that this status
// not be treated as authenticated or authorised in any way whatsoever.
class AccountIdentified extends AccountChosen {
  final bool causedByInteraction;
  const AccountIdentified(super.user, this.causedByInteraction);
}

class AccountAuthenticating extends AccountChosen {
  const AccountAuthenticating(super.user);
}

class AccountCreateRequested extends AccountChosen {
  const AccountCreateRequested(super.user);
}

class AccountCreating extends AccountChosen {
  const AccountCreating(super.user);
}

class AccountAuthenticated extends AccountChosen {
  const AccountAuthenticated(super.user);
}

class AccountAuthenticationBypassed extends AccountChosen {
  const AccountAuthenticationBypassed(super.user);
}

class AccountExpired extends AccountAuthenticated {
  final bool trialAvailable;
  const AccountExpired(super.user, this.trialAvailable);
}

class AccountEmailNotVerified extends AccountAuthenticated {
  const AccountEmailNotVerified(super.user);
}

class AccountEmailChangeRequested extends AccountAuthenticated {
  final String? error;
  const AccountEmailChangeRequested(super.user, this.error);
}

class AccountTrialRestartStarted extends AccountExpired {
  const AccountTrialRestartStarted(super.user, super.trialAvailable);
}

class AccountTrialRestartFinished extends AccountExpired {
  final bool success;
  const AccountTrialRestartFinished(super.user, super.trialAvailable, this.success);
}

class AccountSubscribing extends AccountAuthenticated {
  const AccountSubscribing(super.user);
}

class AccountSubscribed extends AccountAuthenticated {
  const AccountSubscribed(super.user);
}

class AccountSubscribeError extends AccountAuthenticated {
  final String message;
  const AccountSubscribeError(super.user, this.message);
}

class AccountError extends AccountState {}
