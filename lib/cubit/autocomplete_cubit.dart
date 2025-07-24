import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';

part 'autocomplete_state.dart';

class AutocompleteCubit extends Cubit<AutocompleteState> {
  List<String> _usernames = [];

  AutocompleteCubit() : super(AutocompleteInitial());

  void setUsernames(List<String> usernames) {
    _usernames = List.from(usernames);
    emit(AutocompleteUsernamesLoaded(List.unmodifiable(_usernames)));
  }

  void addUsername(String username) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return;
    _usernames.removeWhere((u) => u == trimmed);
    _usernames.insert(0, trimmed);
    emit(AutocompleteUsernamesLoaded(List.unmodifiable(_usernames)));
  }

  List<String> get usernames => List.unmodifiable(_usernames);
}
