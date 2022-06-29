import 'package:flutter/material.dart';
import 'package:kdbx/kdbx.dart';
import '../predefined_icons.dart';
import '../generated/l10n.dart';

class IconChooser extends StatefulWidget {
  final Map<KdbxCustomIcon, Image> customIcons;
  final double? iconSize;
  final Color? iconColor;
  final double? mainAxisSpacing;
  final double? crossAxisSpacing;
  final Color? backgroundColor;

  static late Function reload;
  static late Map<dynamic, dynamic> iconMap; // ick for Dart typing limitations!

  const IconChooser({
    Key? key,
    this.iconSize,
    this.backgroundColor,
    this.mainAxisSpacing,
    this.crossAxisSpacing,
    this.iconColor,
    required this.customIcons,
  }) : super(key: key);

  @override
  State<IconChooser> createState() => _IconChooserState();
}

class _IconChooserState extends State<IconChooser> {
  @override
  void initState() {
    super.initState();
    IconChooser.iconMap = <dynamic, dynamic>{};
    IconChooser.iconMap.addAll(PredefinedIcons.icons.asMap());
    IconChooser.iconMap.addAll(widget.customIcons);
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return AlertDialog(
      title: Text(str.chooseAnIcon),
      content: SizedBox(
        width: 300,
        child: GridView.builder(
            itemCount: IconChooser.iconMap.length,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              childAspectRatio: 1 / 1,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              maxCrossAxisExtent: widget.iconSize != null ? widget.iconSize! + 10 : 50,
            ),
            itemBuilder: (context, index) {
              var item = IconChooser.iconMap.entries.elementAt(index);
              const imageSize = 24.0;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context, item.key is int ? KdbxIcon.values[item.key] : item.key as KdbxCustomIcon);
                },
                child: item.value is IconData
                    ? Icon(
                        item.value,
                        size: widget.iconSize,
                        color: widget.iconColor,
                      )
                    : Container(
                        height: imageSize,
                        width: imageSize,
                        constraints: BoxConstraints(maxWidth: imageSize, minWidth: imageSize),
                        child: Center(
                          child: Container(
                            height: imageSize,
                            width: imageSize,
                            constraints: BoxConstraints(maxWidth: imageSize, minWidth: imageSize),
                            child: (item.value as Image),
                          ),
                        ),
                      ),
              );
            }),
      ),
      actions: [
        TextButton(
          style: ButtonStyle(
            padding: MaterialStateProperty.resolveWith(
              (states) => const EdgeInsets.symmetric(horizontal: 20),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(str.alertClose),
        ),
      ],
    );
  }
}
