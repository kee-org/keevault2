import 'package:flutter/material.dart';
import 'package:keevault/generated/l10n.dart';

class OtpFieldEntryEditor extends StatelessWidget {
  const OtpFieldEntryEditor({
    super.key,
    required this.otpCode,
    required this.elapsed,
    required this.period,
  });

  final String otpCode;
  final int elapsed;
  final int period;

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return StreamBuilder(
      stream: Stream<void>.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: str.otp,
            border: OutlineInputBorder(),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                // height and width are ignored. Probably a flutter bug, worked around by setting
                // padding to consume all remaining space in the prefixIcon space
                height: 8,
                width: 8,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: 1 - (elapsed / period.toDouble()),
                  backgroundColor: Colors.black12,
                ),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(0.0),
            child: Text(
              otpCode,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 5, fontWeight: FontWeight.bold),
              textAlign: TextAlign.start,
            ),
          ),
        );
      },
    );
  }
}
