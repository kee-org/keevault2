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
  const AccountIdentifying(User user) : super(user);
}

// Being Identified means either the remote service was unavailable or it accepted the email address (which
// it typically does for every submission). Thus, there are very limited circumstances where an
// AccountChosen status is unable to progress to AccountIdentified and it is critical that this status
// not be treated as authenticated or authorised in any way whatsoever.
class AccountIdentified extends AccountChosen {
  final bool causedByInteraction;
  const AccountIdentified(User user, this.causedByInteraction) : super(user);
}

class AccountAuthenticating extends AccountChosen {
  const AccountAuthenticating(User user) : super(user);
}

class AccountCreateRequested extends AccountChosen {
  const AccountCreateRequested(User user) : super(user);
}

class AccountCreating extends AccountChosen {
  const AccountCreating(User user) : super(user);
}

class AccountAuthenticated extends AccountChosen {
  const AccountAuthenticated(User user) : super(user);
}

class AccountAuthenticationBypassed extends AccountChosen {
  const AccountAuthenticationBypassed(User user) : super(user);
}

class AccountExpired extends AccountAuthenticated {
  final bool trialAvailable;
  const AccountExpired(User user, this.trialAvailable) : super(user);
}

class AccountEmailNotVerified extends AccountAuthenticated {
  const AccountEmailNotVerified(User user) : super(user);
}

class AccountTrialRestartStarted extends AccountExpired {
  const AccountTrialRestartStarted(User user, bool trialAvailable) : super(user, trialAvailable);
}

class AccountTrialRestartFinished extends AccountExpired {
  final bool success;
  const AccountTrialRestartFinished(User user, bool trialAvailable, this.success) : super(user, trialAvailable);
}

class AccountSubscribing extends AccountAuthenticated {
  const AccountSubscribing(User user) : super(user);
}

class AccountSubscribed extends AccountAuthenticated {
  const AccountSubscribed(User user) : super(user);
}

class AccountSubscribeError extends AccountAuthenticated {
  final String message;
  const AccountSubscribeError(User user, this.message) : super(user);
}

class AccountError extends AccountState {}
