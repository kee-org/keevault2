import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../generated/l10n.dart';
import '../password_strength.dart';

Widget renderPasswordStrength(double strength, double size) {
  return RatingBarIndicator(
    rating: strength,
    itemBuilder: (context, index) => Icon(
      Icons.lock,
      color: Colors.amber,
    ),
    itemCount: 5,
    itemSize: size,
  );
}

class PasswordStrengthWidget extends StatelessWidget {
  final String testValue;
  const PasswordStrengthWidget({super.key, required this.testValue});

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(str.passwordStrength),
          ),
          Flexible(
            child: LayoutBuilder(builder: (context2, constraints) {
              return renderPasswordStrength(
                  testValue.isNotEmpty ? exactStrength(testValue, []) : 0, min(constraints.biggest.width, 160) / 5);
            }),
          ),
        ],
      ),
    );
  }
}
