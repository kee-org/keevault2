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

class AccountAuthenticated extends AccountChosen {
  const AccountAuthenticated(User user) : super(user);
}

class AccountAuthenticationBypassed extends AccountChosen {
  const AccountAuthenticationBypassed(User user) : super(user);
}

class AccountError extends AccountState {}
