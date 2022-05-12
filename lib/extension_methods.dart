import 'dart:collection';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:kdbx/kdbx.dart';
// ignore: implementation_imports
import 'package:kdbx/src/kdbx_xml.dart';
import 'package:keevault/vault_backend/exceptions.dart';

import 'colors.dart';

extension StringExt on String {
  String? takeUnlessBlank() => nullIfBlank();
  String? nullIfBlank() {
    if (isEmpty) {
      return null;
    }
    return this;
  }

  String prepend(String prefix) => '$prefix$this';
}

extension StringToInt on String {
  int toInt() => int.parse(this);
}

extension ListOptGet<T> on List<T> {
  T? optGet(int index) => length > index ? this[index] : null;
}

extension EdgeInsetsExt on EdgeInsets {
  EdgeInsets get onlyTop => EdgeInsets.only(top: top);
}

extension ObjectExt<T> on T {
  T? takeIf(bool Function(T that) predicate) => predicate(this) ? this : null;
  R let<R>(R Function(T that) op) => op(this);
}

extension KdbxEntryColor on KdbxEntry {
  EntryColor? get color {
    final c = backgroundColor.get() ?? KdbxColor.nullColor;
    final colorString = c.rgb;
    return colorString.isNotEmpty ? entryColorFromHex(colorString) : null;
  }

  set color(EntryColor? color) {
    backgroundColor.set(kdbxColors[color]);
  }
}

extension KdbxGroupRecursion on KdbxGroup {
  /// Returns all entries of this group and all sub groups, except for the recycle bin
  LinkedHashMap<String, KdbxEntry> getAllEntriesExceptBin() {
    // ignore: prefer_collection_literals
    final flattenedEntries = LinkedHashMap<String, KdbxEntry>();

    final binUuid = file!.recycleBin?.uuid.uuid;

    groups.forEach((key, value) {
      if (key != binUuid) {
        flattenedEntries.addAll(value.getAllEntries());
      }
    });
    return flattenedEntries..addAll(entries);
  }
}

extension DioHelperHandleException on DioError {
  Future<void> handle(String context, StackTrace s, int retriesRemaining, loginRequiredHandler) async {
    // The request was made and the server responded with a status code
    // that falls out of the range of 2xx and is also not 304.
    if (response != null) {
      switch (response!.statusCode) {
        case 404:
          throw KeeNotFoundException();
        case 403:
          await loginRequiredHandler();
          return;
        case 402:
          throw KeeExceededQuotaException();
        case 400:
          throw KeeInvalidRequestException();
        case 409:
          throw KeeServerConflictException();
        case 500:
          if (retriesRemaining > 0) return;
          throw KeeServerFailException();
        default:
          if (retriesRemaining > 0) return;
          throw KeeUnexpectedException('[$context] DioError with invalid response', this, s);
      }
    } else if (retriesRemaining > 0) {
      return;
    } else {
      // Something happened in setting up or sending the request that triggered an Error
      if (type == DioErrorType.connectTimeout) {
        throw KeeServerUnreachableException();
      }
      if (type == DioErrorType.receiveTimeout || type == DioErrorType.sendTimeout) {
        throw KeeServerTimeoutException();
      }
      if (type == DioErrorType.other) {
        throw KeeServerUnreachableException();
      }
      throw KeeUnexpectedException('[$context] DioError with no response', this, s);
    }
  }
}

String? enumToString(o) => o?.toString().split('.').last;

T? enumFromString<T>(Iterable<T> values, String value) {
  return values.firstWhereOrNull((type) => type.toString().split('.').last == value);
}
