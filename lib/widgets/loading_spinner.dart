import 'package:material_ui/material_ui.dart';

class LoadingSpinner extends StatelessWidget {
  final String tooltip;

  const LoadingSpinner({super.key, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(message: tooltip, child: CircularProgressIndicator());
  }
}
