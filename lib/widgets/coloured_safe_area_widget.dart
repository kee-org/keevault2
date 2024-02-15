import 'package:flutter/material.dart';

class ColouredSafeArea extends StatelessWidget {
  final Widget child;
  final Color? colour;

  const ColouredSafeArea({
    super.key,
    required this.child,
    this.colour,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colour ?? Theme.of(context).appBarTheme.backgroundColor,
      child: SafeArea(
        child: Container(
          color: Theme.of(context).colorScheme.background,
          child: child,
        ),
      ),
    );
  }
}
