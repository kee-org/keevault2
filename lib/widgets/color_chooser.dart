import 'package:flutter/material.dart';

import 'package:keevault/colors.dart';

class ColorChooser extends StatelessWidget {
  const ColorChooser({super.key, required this.onChangeColor, this.currentColor});

  final Function onChangeColor;
  final EntryColor? currentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: EntryColor.values.map((c) => colorBlock(c, theme)).toList());
  }

  Widget colorBlock(EntryColor c, ThemeData theme) {
    final color = theme.brightness == Brightness.dark ? entryColorsContrast[c]! : entryColors[c]!;
    final isCurrentColor = currentColor == c;
    return Container(
      key: Key('${color.value}${theme.brightness.toString()}'),
      margin: EdgeInsets.all(5.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.0),
        color: color,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.8), offset: Offset(1.0, 2.0), blurRadius: 3.0)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChangeColor(c),
          borderRadius: BorderRadius.circular(25.0),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isCurrentColor ? 1.0 : 0.0,
            child: Icon(Icons.done, color: theme.brightness == Brightness.dark ? Colors.black : Colors.white),
          ),
        ),
      ),
    );
  }
}
