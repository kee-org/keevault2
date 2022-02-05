import 'package:flutter/material.dart';
import '../generated/l10n.dart';

class EditableListWidget<T> extends StatefulWidget {
  final List<T> items;
  final bool Function(String value) onAddFromString;
  final void Function(T value) onRemove;
  final String title;
  final String hint;

  const EditableListWidget(
      {Key? key,
      required this.items,
      required this.onAddFromString,
      required this.onRemove,
      required this.title,
      required this.hint})
      : super(key: key);

  @override
  _EditableListWidgetState<T> createState() => _EditableListWidgetState<T>();
}

class _EditableListWidgetState<T> extends State<EditableListWidget<T>> {
  TextEditingController newItemController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final str = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.title,
          style: theme.textTheme.subtitle1,
        ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 12, 12, 12),
                child: TextFormField(
                  controller: newItemController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: widget.hint,
                  ),
                ),
              ),
            ),
            ElevatedButton(
              child: Text(str.add),
              onPressed: () {
                final value = newItemController.text.toLowerCase();
                if (widget.items.contains(value)) return;
                final success = widget.onAddFromString(value);
                if (success) {
                  newItemController.clear();
                }
              },
            ),
          ],
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 220),
          child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: widget.items.length,
              itemBuilder: (BuildContext context, int index) {
                return SizedBox(
                  height: 48,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          widget.items[index].toString(),
                          style: theme.textTheme.subtitle2,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_forever),
                        onPressed: () {
                          widget.onRemove(widget.items[index]);
                        },
                      ),
                    ],
                  ),
                );
              }),
        ),
      ],
    );
  }
}
