import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:kdbx/kdbx.dart';

import 'autofill_matching.dart';

/// What we will offer to save for an Android autofill save request. Nothing here touches the vault: the user decides
/// whether it becomes an entry.
@immutable
class AutofillSaveDraft {
  final String title;
  final String username;

  /// Always protected, like the password of any other entry
  final ProtectedValue password;

  /// The address of the website, only when Android verified it. null = nothing to link.
  final String? url;

  /// The app id, only when Android verified it (and it is not a browser). null = nothing to link.
  final String? androidPackageName;

  /// At least one signal was verified and there is no reason for distrust. This only affects what is linked and which
  /// warnings are shown. It never prevents the user from saving.
  final bool trusted;

  /// Android reported the same text for the username and the password, which is almost certainly a mistake
  final bool sameValue;

  const AutofillSaveDraft({
    required this.title,
    required this.username,
    required this.password,
    required this.url,
    required this.androidPackageName,
    required this.trusted,
    required this.sameValue,
  });

  /// Same per-signal rules as when filling. A browser's id is never an app identity so is never recorded.
  /// An unverified website or app is not recorded here: the user can still add a URL by editing it on the save screen.
  factory AutofillSaveDraft.from(AutofillMetadata metadata, AutofillTarget target) {
    final verifiedApp = target.app?.trust == SignalTrust.verified ? target.app : null;
    final verifiedWeb = target.web?.trust == SignalTrust.verified ? target.web : null;

    final username = metadata.saveInfo?.username ?? '';
    final password = metadata.saveInfo?.password ?? '';

    return AutofillSaveDraft(
      title: verifiedWeb?.domain.domain ?? verifiedApp?.appId ?? target.displayName ?? '[untitled]',
      username: username,
      password: ProtectedValue.fromString(password),
      // Same format as KdbxEntry.addAutofillUrl
      url: verifiedWeb == null ? null : '${verifiedWeb.domain.scheme ?? 'http'}://${verifiedWeb.domain.domain}',
      androidPackageName: verifiedApp?.appId,
      trusted: isTrusted(target),
      sameValue: username.isNotEmpty && username == password,
    );
  }

  /// Notices (e.g. a verified app that also shows web content we won't use) are not a reason for distrust
  static bool isTrusted(AutofillTarget target) => target.hasVerifiedSignal && target.warnings.isEmpty;

  /// Something was linked to the new entry
  bool get hasLinks => url != null || androidPackageName != null;
}
