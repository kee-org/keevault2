import 'package:flutter/material.dart';

class LoadingSpinner extends StatelessWidget {
  final String tooltip;

  const LoadingSpinner({
    Key? key,
    required this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(message: tooltip, child: CircularProgressIndicator());
  }
}
