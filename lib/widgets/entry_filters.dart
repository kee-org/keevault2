import 'package:flutter/material.dart';
import 'package:keevault/generated/l10n.dart';
import 'package:keevault/widgets/text_filter.dart';
import 'color_filter.dart';
import 'group_tree.dart';
import 'label_filter.dart';

enum Category {
  all,
  accessories,
  clothing,
  home,
}

class EntryFilters extends StatelessWidget {
  const EntryFilters({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final MediaQueryData mq = MediaQuery.of(context);
    return DefaultTabController(
      length: 4,
      child: Center(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero,
              color: Theme.of(context).primaryColor,
              child: TabBar(
                labelPadding: EdgeInsets.all(0),
                tabs: [
                  Tab(
                    text: str.group.toUpperCase(),
                    icon: Icon(Icons.folder),
                    iconMargin: EdgeInsets.only(bottom: 3),
                  ),
                  Tab(
                    text: str.label.toUpperCase(),
                    icon: Icon(Icons.label),
                    iconMargin: EdgeInsets.only(bottom: 3),
                  ),
                  Tab(
                    text: str.color.toUpperCase(),
                    icon: Icon(Icons.color_lens),
                    iconMargin: EdgeInsets.only(bottom: 3),
                  ),
                  Tab(
                    text: str.text.toUpperCase(),
                    icon: Icon(Icons.search),
                    iconMargin: EdgeInsets.only(bottom: 3),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 48.0 + mq.padding.bottom),
                child: TabBarView(
                  children: const [
                    GroupTreeWidget(
                      treeMode: GroupTreeMode.all,
                    ),
                    LabelFilterWidget(),
                    ColorFilterWidget(),
                    TextFilterWidget(),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
