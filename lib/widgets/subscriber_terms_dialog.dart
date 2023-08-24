import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

import 'dialog_utils.dart';
import 'package:keevault/generated/l10n.dart';

class SubscriberTermsDialog extends StatelessWidget with DialogMixin<bool> {
  const SubscriberTermsDialog({Key? key}) : super(key: key);

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
              child: Text(str.privacySummaryExplainer),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(str.registrationBlurb2),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(str.registrationBlurb3),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(str.registrationBlurb4),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(str.registrationBlurb5),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(str.registrationBlurb7),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(str.registrationPrivacyOverview1),
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
                      style: theme.textTheme.bodyMedium!.copyWith(
                          color: theme.brightness == Brightness.light ? theme.primaryColor : Colors.white,
                          fontWeight: FontWeight.bold),
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
                      style: theme.textTheme.bodyMedium!.copyWith(
                          color: theme.brightness == Brightness.light ? theme.primaryColor : Colors.white,
                          fontWeight: FontWeight.bold),
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
  String get name => '/dialog/subscriberTerms';
}
