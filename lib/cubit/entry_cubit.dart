import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/extension_methods.dart';
import 'package:keevault/logging/logger.dart';
import 'package:keevault/model/entry.dart';
import 'package:keevault/model/field.dart';

import '../colors.dart';
part 'entry_state.dart';

class EntryCubit extends Cubit<EntryState> {
  EntryCubit() : super(EntryInitial());

  void startEditing(KdbxEntry entry, {bool startDirty = false}) {
    l.t('EntryCubit.startEditing');
    final newEntry = EditEntryViewModel.fromKdbxEntry(entry).let((it) => startDirty ? it.copyWith(isDirty: true) : it);
    emit(EntryLoaded(newEntry));
  }

  void endEditing(KdbxEntry? entry) {
    l.t('EntryCubit.endEditing');
    if (entry != null) {
      (state as EntryLoaded).entry.commit(entry);
    }
    emit(EntryInitial());
  }

  void startCreating(KdbxFile file) {
    emit(EntryLoaded(EditEntryViewModel.create(file.body.rootGroup)));
  }

  void endCreating(KdbxFile? file) {
    if (file != null) {
      final vmEntry = (state as EntryLoaded).entry;
      final entry = KdbxEntry.create(file, vmEntry.group);
      vmEntry.group.addEntry(entry);
      vmEntry.commit(entry);
    }
    emit(EntryInitial());
  }

  void revertToHistoryEntry(KdbxEntry entry, int historyIndex) {
    entry.revertToHistoryEntry(historyIndex);
    entry.file!.clearTagsCache();
    emit(EntryLoaded(EditEntryViewModel.fromKdbxEntry(entry)));
  }

  void removeHistoryEntry(KdbxEntry entry, int historyIndex) {
    throw Exception(
      "Not implemented. Because of the challenge of synchronising adjustments to the list of history items, we can't support targetted history deletion at the moment.",
    );
  }

  update({
    KdbxUuid? uuid,
    bool isDirty = true,
    KdbxGroup? group,
    String? label,
    EntryColor? color,
    BrowserEntrySettings? browserSettings,
    List<Tag>? tags,
    List<String>? androidPackageNames,
  }) {
    final entry = (state as EntryLoaded).entry;
    final updated = entry.copyWith(
      color: color,
      group: group,
      isDirty: isDirty,
      label: label,
      browserSettings: browserSettings,
      uuid: uuid,
      tags: tags,
      androidPackageNames: androidPackageNames,
    );
    emit(EntryLoaded(updated));
  }

  updateGroupByUUID({required String uuid}) {
    final entry = (state as EntryLoaded).entry;
    try {
      final newGroup = entry.group.file!.findGroupByUuid(KdbxUuid(uuid));
      emit(EntryLoaded(entry.copyWith(group: newGroup, isDirty: true)));
    } on StateError {
      l.w('Selected group was deleted before user selected it');
    }
  }

  void changeIcon(KdbxIcon? standard, KdbxCustomIcon? custom) {
    final entry = (state as EntryLoaded).entry;
    final updated = entry.copyWith(isDirty: true);
    if (standard != null) updated.icon = standard;
    updated.customIcon = custom;
    emit(EntryLoaded(updated));
  }

  addField(FieldViewModel field) {
    if (field.fieldKey == null) {
      throw Exception('Invalid field parameter supplied to addField.');
    }
    final entry = (state as EntryLoaded).entry;
    final newList = entry.fields.toList();
    final uniqueName = findUniqueFieldName(newList, field.fieldKey!);
    field =
        uniqueName == field.fieldKey!
            ? field
            : field.copyWith(browserModel: field.browserModel!.copyWith(name: uniqueName));
    newList.add(field);
    final updated = entry.copyWith(fields: newList, isDirty: true);
    emit(EntryLoaded(updated));
  }

  String findUniqueFieldName(List<FieldViewModel> currentFields, String proposedName) {
    var dedupNumber = 0;
    var newName = proposedName;
    while (currentFields.any((f) => f.fieldKey == newName)) {
      dedupNumber++;
      if (dedupNumber > 1000) {
        throw Exception('Failed to find a safe deduplication for a field name. Please choose a different name!');
      }
      newName = '$proposedName ($dedupNumber)';
    }
    return newName;
  }

  removeField(FieldViewModel field) {
    final entry = (state as EntryLoaded).entry;
    final newList = entry.fields.toList();
    newList.remove(field);
    final updated = entry.copyWith(fields: newList, isDirty: true);
    emit(EntryLoaded(updated));
  }

  renameField(KdbxKey? key, String? oldBrowserDisplayName, String newName) {
    final entry = (state as EntryLoaded).entry;
    int fieldIndex;

    if (key == null && (oldBrowserDisplayName?.isEmpty ?? true)) {
      throw Exception('Missing key and oldDisplayName');
    } else if (key != null) {
      fieldIndex = entry.fields.indexWhere((f) => f.key == key);
      if (fieldIndex == -1) {
        l.e('Field missing: ${key.key} (Custom/Both)');
        return;
      }
    } else {
      fieldIndex = entry.fields.indexWhere((f) => f.browserModel?.name == oldBrowserDisplayName);
      if (fieldIndex == -1) {
        l.e('Field missing: $oldBrowserDisplayName (Json)');
        return;
      }
    }
    final newList = entry.fields.toList();
    final currentField = entry.fields[fieldIndex];

    final updatedFieldName = findUniqueFieldName(newList, newName);
    final updatedField =
        currentField.fieldStorage == FieldStorage.JSON
            ? currentField.copyWith(browserModel: currentField.browserModel!.copyWith(name: updatedFieldName))
            : currentField.copyWith(key: KdbxKey(updatedFieldName), name: updatedFieldName);

    newList.replaceRange(fieldIndex, fieldIndex + 1, [updatedField]);
    final updated = entry.copyWith(fields: newList, isDirty: true);
    emit(EntryLoaded(updated));
  }

  updateField(
    KdbxKey? key,
    String? oldBrowserDisplayName, {
    bool isDirty = true,
    String? localisedCommonName,
    bool? protect,
    TextInputType? keyboardType,
    bool? autocorrect,
    bool? enableSuggestions,
    TextCapitalization? textCapitalization,
    IconData? icon,
    bool? showIfEmpty,
    Field? browserModel,
    StringValue? value,
    String? newCustomFieldName,
  }) {
    final entry = (state as EntryLoaded).entry;
    int fieldIndex;

    if (key == null && (oldBrowserDisplayName?.isEmpty ?? true)) {
      throw Exception('Missing key and oldDisplayName');
    } else if (key != null) {
      fieldIndex = entry.fields.indexWhere((f) => f.key == key);
      if (fieldIndex == -1) {
        l.e('Field missing: ${key.key} (Custom/Both)');
        return;
      }
    } else {
      fieldIndex = entry.fields.indexWhere((f) => f.browserModel?.name == oldBrowserDisplayName);
      if (fieldIndex == -1) {
        l.e('Field missing: $oldBrowserDisplayName (Json)');
        return;
      }
    }
    final newList = entry.fields.toList();

    final updatedField = entry.fields[fieldIndex].copyWith(
      key: newCustomFieldName != null ? KdbxKey(newCustomFieldName) : key,
      autocorrect: autocorrect,
      browserModel: browserModel,
      enableSuggestions: enableSuggestions,
      icon: icon,
      isDirty: isDirty,
      keyboardType: keyboardType,
      localisedCommonName: localisedCommonName,
      name: newCustomFieldName,
      protect: protect,
      showIfEmpty: showIfEmpty,
      textCapitalization: textCapitalization,
      value: value,
    );
    newList.replaceRange(fieldIndex, fieldIndex + 1, [updatedField]);
    final updated = entry.copyWith(fields: newList, isDirty: true);
    emit(EntryLoaded(updated));
  }

  void changeColor(EntryColor color) {
    final entry = (state as EntryLoaded).entry;
    final updated = entry.copyWith(isDirty: true);
    if (updated.color == color) {
      updated.color = null;
    } else {
      updated.color = color;
    }
    emit(EntryLoaded(updated));
  }

  void attachFile({required String fileName, required Uint8List bytes}) {
    final entry = (state as EntryLoaded).entry;
    final binary = entry.createBinaryForCopy(name: fileName, bytes: bytes);
    final updated = entry.copyWith(isDirty: true, binaryMapEntries: [...entry.binaryMapEntries, binary]);
    emit(EntryLoaded(updated));
  }

  void removeFile({required KdbxKey key}) {
    final entry = (state as EntryLoaded).entry;
    final updated = entry.copyWith(
      isDirty: true,
      binaryMapEntries: entry.binaryMapEntries.where((b) => b.key != key).toList(),
    );
    emit(EntryLoaded(updated));
  }
}
