import 'package:flutter/material.dart';

class ColouredSafeArea extends StatelessWidget {
  final Widget child;
  final Color? colour;

  const ColouredSafeArea({
    Key? key,
    required this.child,
    this.colour,
  }) : super(key: key);

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
