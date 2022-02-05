import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:kdbx/kdbx.dart';
import 'package:meta/meta.dart';

import '../extension_methods.dart';

part 'sort_state.dart';

class SortCubit extends Cubit<SortState> {
  SortCubit() : super(SortedState(null));

  Future<void> reorder(SortMode mode) async {
    await Settings.setValue('currentSortOrder', enumToString(mode));
    emit(SortedState(mode));
  }
}
