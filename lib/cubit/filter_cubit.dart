import 'package:bloc/bloc.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/model/search_options.dart';
import '../colors.dart';
import 'package:meta/meta.dart';
import 'package:keevault/extension_methods.dart';

part 'filter_state.dart';

class FilterCubit extends Cubit<FilterState> {
  FilterCubit() : super(FilterInitial());

  reset() {
    emit(FilterInitial());
  }

  void start(String rootUuid, bool includeChildGroups) {
    emit(FilterActive(
      rootUuid,
      includeChildGroups,
      const [],
      const [],
      '',
      SearchOptions(),
      rootUuid,
    ));
  }

  changeGroup(String? uuid) {
    final fa = state as FilterActive;
    emit(FilterActive(
      uuid ?? fa.rootGroupUuid,
      fa.includeChildGroups,
      fa.colors,
      fa.tags,
      fa.text,
      fa.textOptions,
      fa.rootGroupUuid,
    ));
  }

  changeText(String text) {
    final fa = state as FilterActive;
    emit(FilterActive(
      fa.groupUuid,
      fa.includeChildGroups,
      fa.colors,
      fa.tags,
      text,
      fa.textOptions,
      fa.rootGroupUuid,
    ));
  }

  toggleTag(String tagInput) {
    final fa = state as FilterActive;
    final tag = tagInput.toLowerCase();
    final newList = fa.tags.toList();
    final didRemoveTag = newList.remove(tag);
    if (!didRemoveTag) {
      newList.add(tag);
    }
    emit(FilterActive(
      fa.groupUuid,
      fa.includeChildGroups,
      fa.colors,
      newList,
      fa.text,
      fa.textOptions,
      fa.rootGroupUuid,
    ));
  }

  toggleColor(EntryColor color) {
    final fa = state as FilterActive;
    final newList = fa.colors.toList();
    final didRemoveColor = newList.remove(color);
    if (!didRemoveColor) {
      newList.add(color);
    }
    emit(FilterActive(
      fa.groupUuid,
      fa.includeChildGroups,
      newList,
      fa.tags,
      fa.text,
      fa.textOptions,
      fa.rootGroupUuid,
    ));
  }

  void updateTextOptions(SearchOptions textOptions) {
    final fa = state as FilterActive;
    emit(FilterActive(
      fa.groupUuid,
      fa.includeChildGroups,
      fa.colors,
      fa.tags,
      fa.text,
      textOptions,
      fa.rootGroupUuid,
    ));
  }

  void reFilter(List<String> validTags) {
    final validTagsLowerCase = validTags.map((t) => t.toLowerCase()).toList();
    final fa = state as FilterActive;
    emit(FilterActive(
      fa.groupUuid,
      fa.includeChildGroups,
      fa.colors,
      fa.tags.where((t) => validTagsLowerCase.contains(t)).toList(),
      fa.text,
      fa.textOptions,
      fa.rootGroupUuid,
    ));
  }

  bool entryMatches(KdbxEntry entry) {
    final fa = state as FilterActive;
    final quickCheck = fa.colors.isEmpty &&
        (fa.tags.isEmpty || entry.tags.get()!.any((tag) => fa.tags.contains(tag.toLowerCase()))) &&
        (fa.colors.isEmpty || fa.colors.contains(entry.color));

    if (!quickCheck) {
      return false;
    }
    if (fa.text.isEmpty) {
      return true;
    }

    final opts = fa.textOptions;
    late Pattern search;
    var comparer = (String haystack) => (haystack.toLowerCase().contains(search)) ? true : false;
    if (opts.regex) {
      try {
        search = RegExp(fa.text, caseSensitive: opts.caseSensitive);
      } catch (e) {
        return false;
      }
    } else if (opts.caseSensitive) {
      search = fa.text;
      comparer = (String haystack) => (haystack.contains(search)) ? true : false;
    } else {
      search = fa.text.toLowerCase();
    }
    if (matchEntryVersion(entry, opts, comparer)) {
      return true;
    }
    if (opts.history) {
      for (int i = 0, len = entry.history.length; i < len; i++) {
        if (matchEntryVersion(entry.history[i], opts, comparer)) {
          return true;
        }
      }
    }
    return false;
  }

  bool matchEntryVersion(KdbxEntry entry, SearchOptions opts, bool Function(String) compare) {
    for (var mapEntry in entry.stringEntries
        .where((me) => !['KPRPC JSON', 'TOTP Seed', 'TOTP Settings', 'OTPAuth'].contains(me.key.key))) {
      if (mapEntry.key == KdbxKeyCommon.USER_NAME) {
        if (opts.username && compare(mapEntry.value!.getText())) {
          return true;
        }
      } else if (mapEntry.key == KdbxKeyCommon.URL) {
        if (opts.urls && compare(mapEntry.value!.getText())) {
          return true;
        }
      } else if (mapEntry.key == KdbxKeyCommon.NOTES) {
        if (opts.notes && compare(mapEntry.value!.getText())) {
          return true;
        }
      } else if (mapEntry.key == KdbxKeyCommon.PASSWORD) {
        if (opts.password && compare(mapEntry.value!.getText())) {
          return true;
        }
      } else if (mapEntry.key == KdbxKeyCommon.TITLE) {
        if (opts.title && compare(mapEntry.value!.getText())) {
          return true;
        }
      } else if (mapEntry.value is PlainValue && opts.other) {
        if (compare(mapEntry.value!.getText())) {
          return true;
        }
      } else if (mapEntry.value is ProtectedValue && opts.otherProtected) {
        if (compare(mapEntry.value!.getText())) {
          return true;
        }
      }
    }
    if (opts.urls && entry.browserSettings.includeUrls.any((p) => compare(p is RegExp ? p.pattern : p as String))) {
      return true;
    }
    return false;
  }
}
