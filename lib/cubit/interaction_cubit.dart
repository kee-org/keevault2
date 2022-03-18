import 'package:bloc/bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:meta/meta.dart';
import 'dart:convert';

part 'interaction_state.dart';

class InteractionCubit extends Cubit<InteractionState> {
  InteractionCubit()
      : super(InteractionBasic(
          Settings.getValue('interactionAnyEntrySavedCount', 0),
          Settings.getValue('interactionAnyDatabaseSavedCount', 0),
          Settings.getValue('interactionAnyDatabaseOpenedCount', 0),
          DateTime.fromMillisecondsSinceEpoch(
              Settings.getValue('interactionInstalledBefore', DateTime.now().toUtc().millisecondsSinceEpoch)),
          DateTime.fromMillisecondsSinceEpoch(Settings.getValue('interactionAnyDatabaseLastOpenedAt', 0)),
        ));

  Future<void> databaseOpened() async {
    final now = DateTime.now().toUtc();
    final ibState = (state as InteractionBasic);
    final newOpenedCount = ibState.anyDatabaseOpenedCount + 1;
    bool trackInitialInstall = false;
    List<Future<void>> setValueOperations = [];
    if (ibState.anyDatabaseLastOpenedAt == DateTime.fromMillisecondsSinceEpoch(0).toUtc()) {
      trackInitialInstall = true;
      setValueOperations.add(Settings.setValue('interactionInstalledBefore', now.millisecondsSinceEpoch));
    }
    setValueOperations.add(Settings.setValue('interactionAnyDatabaseLastOpenedAt', now.millisecondsSinceEpoch));
    setValueOperations.add(Settings.setValue('interactionAnyDatabaseOpenedCount', newOpenedCount));
    await Future.wait(setValueOperations);
    emit(ibState.copyWith(
      anyDatabaseLastOpenedAt: now,
      anyDatabaseOpenedCount: newOpenedCount,
      installedBefore: trackInitialInstall ? now : null,
    ));
  }

  Future<void> databaseSaved() async {
    final ibState = (state as InteractionBasic);
    final newSavedCount = ibState.anyDatabaseSavedCount + 1;
    await Settings.setValue('interactionAnyDatabaseSavedCount', newSavedCount);
    emit(ibState.copyWith(anyDatabaseSavedCount: newSavedCount));
  }

  Future<void> entrySaved() async {
    final ibState = (state as InteractionBasic);
    final newSavedCount = ibState.anyEntrySavedCount + 1;
    await Settings.setValue('interactionAnyEntrySavedCount', newSavedCount);
    emit(ibState.copyWith(anyEntrySavedCount: newSavedCount));
  }
}
