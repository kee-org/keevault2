import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_treeview/flutter_treeview.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/cubit/vault_cubit.dart';

//TODO:f: Find a way to reduce duplication with group_tree.dart
class GroupMoveTreeWidget extends StatelessWidget {
  const GroupMoveTreeWidget({super.key, required this.initialSelectedUuid, required this.title});

  final String initialSelectedUuid;
  final String title;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VaultCubit, VaultState>(
        buildWhen: (previous, current) => current is VaultLoaded,
        builder: (context, state) {
          if (state is VaultLoaded) {
            final root = state.vault.files.current.body.rootGroup;
            final bin = state.vault.files.current.recycleBin;

            final nodes = [
              Node<String>(
                key: root.uuid.uuid,
                label: root.name.get() ?? 'My Kee Vault',
                data: root.uuid.uuid,
                expanded: true,
                children: kdbxGroupToNodes(root, 1, (group) => group != bin),
              ),
            ];

            return GroupMoveTreeListWidget(
              nodes: nodes,
              initialSelectedUuid: initialSelectedUuid,
              title: title,
            );
          }
          return Container();
        });
  }
}

//TODO:f: Find a way to reduce duplication with group_tree.dart
class EntryMoveTreeWidget extends StatelessWidget {
  const EntryMoveTreeWidget({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VaultCubit, VaultState>(
        buildWhen: (previous, current) => current is VaultLoaded,
        builder: (context, state) {
          if (state is VaultLoaded) {
            final root = state.vault.files.current.body.rootGroup;
            final bin = state.vault.files.current.recycleBin;

            final nodes = [
              Node<String>(
                key: root.uuid.uuid,
                label: root.name.get() ?? 'My Kee Vault',
                data: root.uuid.uuid,
                expanded: true,
                children: kdbxGroupToNodes(root, 1, (group) => group != bin),
              ),
            ];

            return EntryMoveTreeListWidget(nodes: nodes, title: title);
          }
          return Container();
        });
  }
}

List<Node<String>> kdbxGroupToNodes(KdbxGroup root, int depth, bool Function(KdbxGroup) filter) {
  final nodes = root.groups.values
      .where((group) => filter(group))
      .map((value) => Node<String>(
            key: value.uuid.uuid,
            label: value.name.get() ?? '[no name]',
            data: value.uuid.uuid,
            expanded: depth < 6,
            children: kdbxGroupToNodes(value, depth + 1, filter),
          ))
      .toList();
  return nodes;
}

abstract class MoveTreeListWidget extends StatefulWidget {
  final List<Node<String>> nodes;
  final String title;
  const MoveTreeListWidget({
    super.key,
    required this.nodes,
    required this.title,
  });
}

abstract class _MoveTreeListWidgetState<T extends MoveTreeListWidget> extends State<T> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<VaultCubit, VaultState>(
        buildWhen: (previous, current) => current is VaultLoaded,
        builder: (context, state) {
          if (state is VaultLoaded) {
            TreeViewTheme treeViewTheme = TreeViewTheme(
              labelOverflow: TextOverflow.ellipsis,
              colorScheme:
                  theme.colorScheme.copyWith(primary: theme.focusColor, onPrimary: theme.colorScheme.secondary),
              expanderTheme: ExpanderThemeData(
                animated: true,
                position: ExpanderPosition.start,
                type: ExpanderType.chevron,
                size: 32,
                modifier: ExpanderModifier.none,
                color: theme.colorScheme.secondary,
              ),
              parentLabelStyle: TextStyle(
                fontWeight: FontWeight.normal,
              ),
              horizontalSpacing: 15,
              verticalSpacing: 15,
              parentLabelOverflow: TextOverflow.ellipsis,
            );
            return Container(
              color: theme.colorScheme.background,
              child: SafeArea(
                minimum: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    Expanded(child: _buildTreeView(context, treeViewTheme)),
                  ],
                ),
              ),
            );
          }
          return Container();
        });
  }

  Widget _buildTreeView(BuildContext context, TreeViewTheme treeViewTheme);
}

class GroupMoveTreeListWidget extends MoveTreeListWidget {
  final String initialSelectedUuid;
  const GroupMoveTreeListWidget({
    required this.initialSelectedUuid,
    super.key,
    required super.nodes,
    required super.title,
  });

  @override
  State<GroupMoveTreeListWidget> createState() => _GroupMoveTreeListWidgetState();
}

class _GroupMoveTreeListWidgetState extends _MoveTreeListWidgetState<GroupMoveTreeListWidget> {
  late TreeViewController<String> _treeViewController = TreeViewController<String>(children: widget.nodes);

  @override
  Widget _buildTreeView(BuildContext context, TreeViewTheme treeViewTheme) {
    final selectedGroup = widget.initialSelectedUuid;
    _treeViewController = _treeViewController.copyWith(selectedKey: selectedGroup);
    return TreeView<String>(
        controller: _treeViewController,
        allowParentSelect: true,
        shrinkWrap: true,
        supportParentDoubleTap: false,
        onNodeTap: (key) {
          Node<String>? selectedNode = _treeViewController.getNode(key);
          BlocProvider.of<VaultCubit>(context)
              .moveGroup(groupUuid: widget.initialSelectedUuid, newParentUuid: selectedNode!.data!);
          Navigator.of(context).pop(true);
        },
        onExpansionChanged: (String key, bool expanded) {
          Node<String>? node = _treeViewController.getNode(key);
          if (node != null) {
            final updated = _treeViewController.updateNode(key, node.copyWith(expanded: expanded));
            setState(() {
              _treeViewController = _treeViewController.copyWith(children: updated);
            });
          }
        },
        theme: treeViewTheme);
  }
}

class EntryMoveTreeListWidget extends MoveTreeListWidget {
  const EntryMoveTreeListWidget({
    super.key,
    required super.nodes,
    required super.title,
  });

  @override
  State<EntryMoveTreeListWidget> createState() => _EntryMoveTreeListWidgetState();
}

class _EntryMoveTreeListWidgetState extends _MoveTreeListWidgetState<EntryMoveTreeListWidget> {
  late TreeViewController<String> _treeViewController = TreeViewController<String>(children: widget.nodes);

  @override
  Widget _buildTreeView(BuildContext context, TreeViewTheme treeViewTheme) {
    return BlocBuilder<EntryCubit, EntryState>(
      builder: (context, state) {
        if (state is! EntryLoaded) return Container();
        final selectedGroup = state.entry.group.uuid.uuid;
        _treeViewController = _treeViewController.copyWith(selectedKey: selectedGroup);
        return TreeView<String>(
            controller: _treeViewController,
            allowParentSelect: true,
            shrinkWrap: true,
            supportParentDoubleTap: false,
            onNodeTap: (key) {
              Node<String>? selectedNode = _treeViewController.getNode(key);
              final nav = Navigator.of(context);
              BlocProvider.of<EntryCubit>(context).updateGroupByUUID(uuid: selectedNode!.data!);
              nav.pop(true);
            },
            onExpansionChanged: (String key, bool expanded) {
              Node<String>? node = _treeViewController.getNode(key);
              if (node != null) {
                final updated = _treeViewController.updateNode(key, node.copyWith(expanded: expanded));
                setState(() {
                  _treeViewController = _treeViewController.copyWith(children: updated);
                });
              }
            },
            theme: treeViewTheme);
      },
    );
  }
}
