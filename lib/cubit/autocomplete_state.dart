part of 'autocomplete_cubit.dart';

@immutable
abstract class AutocompleteState {}

class AutocompleteInitial extends AutocompleteState {}

class AutocompleteUsernamesLoaded extends AutocompleteState {
  final List<String> usernames;
  AutocompleteUsernamesLoaded(this.usernames);
}
