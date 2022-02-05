import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

import 'dialog_utils.dart';
import 'package:keevault/generated/l10n.dart';

class FreeUserTermsDialog extends StatelessWidget with DialogMixin<bool> {
  const FreeUserTermsDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    const tosLink = 'https://www.kee.pm/keevault/tos/';
    const privacyLink = 'https://www.kee.pm/keevault/privacy/';
    return AlertDialog(
      title: null,
      content: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(str.freeUserTermsPopup1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(str.freeUserTermsPopup2),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(str.freeUserTermsPopup3),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Link(
                uri: Uri.parse(tosLink),
                target: LinkTarget.blank,
                builder: (context, followLink) {
                  return InkWell(
                    onTap: followLink,
                    child: Text(
                      tosLink,
                      style: theme.textTheme.bodyText2!.copyWith(color: theme.primaryColor),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Link(
                uri: Uri.parse(privacyLink),
                target: LinkTarget.blank,
                builder: (context, followLink) {
                  return InkWell(
                    onTap: followLink,
                    child: Text(
                      privacyLink,
                      style: theme.textTheme.bodyText2!.copyWith(color: theme.primaryColor),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(str.freeUserTermsPopup4),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(str.alertOk),
        ),
      ],
    );
  }

  @override
  String get name => '/dialog/freeUserTerms';
}
