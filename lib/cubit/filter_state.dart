part of 'filter_cubit.dart';

@immutable
abstract class FilterState {}

class FilterInitial extends FilterState {}

class FilterActive extends FilterState {
  final String rootGroupUuid;
  final String groupUuid;
  final bool includeChildGroups;
  final List<EntryColor> colors;
  final List<String> tags;
  final String text;
  final SearchOptions textOptions;

  FilterActive(
    this.groupUuid,
    this.includeChildGroups,
    this.colors,
    this.tags,
    this.text,
    this.textOptions,
    this.rootGroupUuid,
  );
}
