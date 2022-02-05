part of 'sort_cubit.dart';

enum SortMode {
  titleAsc,
  titleDesc,
  modifiedAsc,
  modifiedDesc,
  createdAsc,
  createdDesc,
}

@immutable
abstract class SortState {}

class SortedState extends SortState {
  late final SortMode mode;

  SortedState(SortMode? mode) {
    if (mode == null) {
      final currentSortOrder = Settings.getValue<String>('currentSortOrder', 'modifiedDesc');
      mode = currentSortOrder.toSortMode() ?? SortMode.modifiedDesc;
    }
    // ignore: prefer_initializing_formals
    this.mode = mode;
  }

  int Function(KdbxEntry, KdbxEntry) get comparator {
    switch (mode) {
      case SortMode.titleAsc:
        return (KdbxEntry a, KdbxEntry b) => (a.getString(KdbxKeyCommon.TITLE)?.getText().toLowerCase() ?? '')
            .compareTo((b.getString(KdbxKeyCommon.TITLE)?.getText().toLowerCase() ?? ''));
      case SortMode.titleDesc:
        return (KdbxEntry a, KdbxEntry b) => (b.getString(KdbxKeyCommon.TITLE)?.getText().toLowerCase() ?? '')
            .compareTo((a.getString(KdbxKeyCommon.TITLE)?.getText().toLowerCase() ?? ''));
      case SortMode.modifiedAsc:
        return (KdbxEntry a, KdbxEntry b) => (a.times.lastModificationTime.get() ?? DateTime.now())
            .compareTo(b.times.lastModificationTime.get() ?? DateTime.now());
      case SortMode.modifiedDesc:
        return (KdbxEntry a, KdbxEntry b) => (b.times.lastModificationTime.get() ?? DateTime.now())
            .compareTo(a.times.lastModificationTime.get() ?? DateTime.now());
      case SortMode.createdAsc:
        return (KdbxEntry a, KdbxEntry b) =>
            (a.times.creationTime.get() ?? DateTime.now()).compareTo(b.times.creationTime.get() ?? DateTime.now());
      case SortMode.createdDesc:
        return (KdbxEntry a, KdbxEntry b) =>
            (b.times.creationTime.get() ?? DateTime.now()).compareTo(a.times.creationTime.get() ?? DateTime.now());
    }
  }
}

extension EnumParserSortMode on String {
  SortMode? toSortMode() {
    return SortMode.values.firstWhereOrNull((e) => e.toString().toLowerCase() == 'sortmode.$this'.toLowerCase());
  }
}
