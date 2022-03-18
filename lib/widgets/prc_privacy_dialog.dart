import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

import 'dialog_utils.dart';
import 'package:keevault/generated/l10n.dart';

class PrcPrivacyDialog extends StatelessWidget with DialogMixin<bool> {
  const PrcPrivacyDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    const privacyLink = 'https://www.kee.pm/keevault/privacy/';
    return AlertDialog(
      title: null,
      scrollable: true,
      content: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(str.prcRegistrationPrivacy1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(str.prcRegistrationPrivacy2),
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
                      style: theme.textTheme.bodyText2!.copyWith(color: theme.colorScheme.tertiary),
                    ),
                  );
                },
              ),
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
  String get name => '/dialog/prcPrivacySummary';
}
