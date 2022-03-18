import 'package:flutter/material.dart';
import 'dialog_utils.dart';
import 'package:keevault/generated/l10n.dart';

class PRCDismissDialog extends StatelessWidget with DialogMixin<int> {
  const PRCDismissDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return AlertDialog(
      title: null,
      scrollable: true,
      content: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(str.prcRegistrationReminderDelayRemindMe),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(3),
                child: Text(str.prcRegistrationReminderDelay3days.toUpperCase()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(21),
                child: Text(str.prcRegistrationReminderDelay3weeks.toUpperCase()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(90),
                child: Text(str.prcRegistrationReminderDelay3months.toUpperCase()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(-1),
                child: Text(str.prcRegistrationReminderDelayNever.toUpperCase()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  String get name => '/dialog/prcDismiss';
}
