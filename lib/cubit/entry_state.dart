part of 'entry_cubit.dart';

@immutable
abstract class EntryState {}

class EntryInitial extends EntryState {}

class EntryLoaded extends EntryState {
  final EditEntryViewModel entry;

  EntryLoaded(this.entry);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EntryLoaded && other.entry == entry;
  }

  @override
  int get hashCode => entry.hashCode;
}
