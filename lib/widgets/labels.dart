import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chips_input/flutter_chips_input.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/model/entry.dart';
import '../generated/l10n.dart';

class LabelsWidget extends StatefulWidget {
  final List<Tag> otherKnownTags;
  final List<Tag> tags;
  const LabelsWidget({Key? key, required this.otherKnownTags, required this.tags}) : super(key: key);

  @override
  _LabelsWidgetState createState() => _LabelsWidgetState();
}

class _LabelsWidgetState extends State<LabelsWidget> {
  final _chipKey = GlobalKey<ChipsInputState>();
  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.0),
      child: ChipsInput(
        key: _chipKey,
        initialValue: widget.tags,
        initialSuggestions: widget.otherKnownTags,
        keyboardAppearance: Brightness.dark,
        suggestionsBoxMaxHeight: 250,
        textCapitalization: TextCapitalization.words,
        enabled: true,
        maxChips: 25,
        textStyle: const TextStyle(height: 1.5, fontFamily: 'Roboto', fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.label),
          labelText: str.labels,
          border: OutlineInputBorder(),
        ),
        findSuggestions: (String query) {
          if (query.isNotEmpty) {
            var lowercaseQuery = query.toLowerCase();
            final otherMatchingTags = widget.otherKnownTags.where((tag) {
              return tag.lowercase.contains(lowercaseQuery);
            }).toList(growable: false)
              ..sort((a, b) => a.lowercase.indexOf(lowercaseQuery).compareTo(b.lowercase.indexOf(lowercaseQuery)));
            if (otherMatchingTags.followedBy(widget.tags).any((tag) => tag.lowercase == lowercaseQuery)) {
              return otherMatchingTags;
            }
            return [Tag(query, false), ...otherMatchingTags];
          }
          return widget.otherKnownTags;
        },
        onChanged: (List<Tag> tags) {
          final cubit = BlocProvider.of<EntryCubit>(context);
          cubit.update(tags: tags);
        },
        chipBuilder: (context, ChipsInputState<Tag> state, Tag tag) {
          return InputChip(
            key: ObjectKey(tag),
            label: Text(tag.name),
            padding: EdgeInsets.all(0.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4.0))),
            onDeleted: () => state.deleteChip(tag),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: EdgeInsets.only(left: 8.0),
          );
        },
        suggestionBuilder: (context, ChipsInputState<Tag> state, Tag tag) {
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12),
            horizontalTitleGap: 4,
            key: ObjectKey(tag),
            leading: tag.isStored ? Icon(Icons.label_outline) : Icon(Icons.add_circle),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: theme.brightness == Brightness.dark ? Colors.grey.shade900 : null,
                    label: Text(
                      tag.name,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                    padding: EdgeInsets.all(0.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4.0))),
                  ),
                ),
              ],
            ),
            onTap: () => state.selectSuggestion(tag),
          );
        },
        suggestionListBuilder: (context, child) => Material(
          child: Container(
              color: theme.brightness == Brightness.dark ? Colors.grey.shade800 : theme.secondaryHeaderColor,
              child: child),
          elevation: 4.0,
          type: MaterialType.canvas,
        ),
      ),
    );
  }
}
