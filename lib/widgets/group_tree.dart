import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_treeview/flutter_treeview.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/cubit/filter_cubit.dart';
import 'package:keevault/cubit/vault_cubit.dart';
import 'package:keevault/generated/l10n.dart';

import 'dialog_utils.dart';
import 'group_move_tree.dart';

enum GroupTreeMode { all, standardOnly }

class GroupTreeWidget extends StatelessWidget {
  final GroupTreeMode treeMode;

  const GroupTreeWidget({super.key, required this.treeMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final str = S.of(context);
    return BlocBuilder<VaultCubit, VaultState>(
      buildWhen: (previous, current) => current is VaultLoaded,
      builder: (context, state) {
        if (state is VaultLoaded) {
          final root = state.vault.files.current.body.rootGroup;
          final bin = state.vault.files.current.recycleBin;

          final nodes = [
            Node<GroupData>(
              key: root.uuid.uuid,
              label: root.name.get() ?? 'My Kee Vault',
              data: GroupData(uuid: root.uuid.uuid, isDeleted: false, isMovable: false),
              expanded: true,
              children: kdbxGroupToNodes(root, 1, (group) => group != bin),
            ),
          ];

          List<Node<GroupData>>? binNodes;
          if (treeMode == GroupTreeMode.all && bin != null) {
            binNodes = [
              Node<GroupData>(
                key: bin.uuid.uuid,
                label: bin.name.get() ?? str.menuTrash,
                data: GroupData(uuid: bin.uuid.uuid, isDeleted: false, isMovable: false, isRecycleBin: true),
                expanded: false,
                children: kdbxGroupToNodes(bin, 1, (_) => true),
              ),
            ];
          }

          return BlocBuilder<FilterCubit, FilterState>(
            builder: (context, state) {
              if (state is! FilterActive) return Container();
              //TODO:f: Add a "search for group name" textfield which can then filter the list of nodes that we supply
              final selectedGroup = state.groupUuid;
              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GroupTreeListWidget(nodes: nodes, selectedGroupUuid: selectedGroup),
                        ),
                        if (binNodes != null)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.symmetric(horizontal: BorderSide(color: theme.canvasColor, width: 2)),
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: (MediaQuery.of(context).size.height - 300) * 0.6),
                              child: GroupTreeListWidget(nodes: binNodes, selectedGroupUuid: selectedGroup),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8.0, left: 8, right: 16),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.info, color: theme.textTheme.bodySmall!.color),
                        ),
                        Expanded(child: Text(str.longPressGroupExplanation, style: theme.textTheme.bodySmall)),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        }
        return Container();
      },
    );
  }
}

List<Node<GroupData>> kdbxGroupToNodes(KdbxGroup group, int depth, bool Function(KdbxGroup) filter) {
  final nodes = group.groups.values
      .where((subgroup) => filter(subgroup))
      .map(
        (subgroup) => Node<GroupData>(
          key: subgroup.uuid.uuid,
          label: subgroup.name.get() ?? '[no name]',
          data: GroupData(
            uuid: subgroup.uuid.uuid,
            isDeleted: subgroup.isInRecycleBin,
            isMovable: !subgroup.isInRecycleBin,
          ),
          expanded: depth < 6,
          children: kdbxGroupToNodes(subgroup, depth + 1, filter),
        ),
      )
      .toList();
  return nodes;
}

class GroupData {
  final String uuid;
  final bool isMovable;
  final bool isDeleted;
  final bool isRecycleBin;

  GroupData({required this.isMovable, required this.isDeleted, required this.uuid, this.isRecycleBin = false});
}

class GroupTreeListWidget extends StatefulWidget {
  final List<Node<GroupData>> nodes;
  final String selectedGroupUuid;
  const GroupTreeListWidget({super.key, required this.nodes, required this.selectedGroupUuid});
  @override
  State<GroupTreeListWidget> createState() => _GroupTreeListWidgetState();
}

class _GroupTreeListWidgetState extends State<GroupTreeListWidget> {
  late TreeViewController<GroupData> _treeViewController;
  String? _managedGroupUuid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<VaultCubit, VaultState>(
      buildWhen: (previous, current) => current is VaultLoaded,
      builder: (context, state) {
        if (state is VaultLoaded) {
          _treeViewController = TreeViewController<GroupData>(children: widget.nodes);
          TreeViewTheme treeViewTheme = TreeViewTheme(
            labelOverflow: TextOverflow.ellipsis,
            colorScheme: theme.colorScheme.copyWith(primary: theme.focusColor, onPrimary: theme.colorScheme.secondary),
            expanderTheme: ExpanderThemeData(
              animated: true,
              position: ExpanderPosition.start,
              type: ExpanderType.chevron,
              size: 32,
              modifier: ExpanderModifier.none,
              color: theme.colorScheme.secondary,
            ),
            parentLabelStyle: TextStyle(fontWeight: FontWeight.normal),
            horizontalSpacing: 15,
            verticalSpacing: 15,
            parentLabelOverflow: TextOverflow.ellipsis,
          );
          return BlocBuilder<FilterCubit, FilterState>(
            builder: (context, state) {
              if (state is! FilterActive) return Container();
              final selectedGroup = state.groupUuid;
              _treeViewController = _treeViewController.copyWith(selectedKey: selectedGroup);
              return TreeView<GroupData>(
                controller: _treeViewController,
                allowParentSelect: true,
                shrinkWrap: true,
                supportParentDoubleTap: false,
                onNodeTap: (key) {
                  Node<GroupData>? selectedNode = _treeViewController.getNode(key);
                  BlocProvider.of<FilterCubit>(context).changeGroup(selectedNode!.data!.uuid);
                },
                onNodeLongPress: (key) {
                  setState(() {
                    if (_managedGroupUuid == key) {
                      _managedGroupUuid = null;
                    } else {
                      _managedGroupUuid = key;
                    }
                  });
                },
                onExpansionChanged: (String key, bool expanded) {
                  Node<GroupData>? node = _treeViewController.getNode(key);
                  if (node != null) {
                    final updated = _treeViewController.updateNode(key, node.copyWith(expanded: expanded));
                    setState(() {
                      _treeViewController = _treeViewController.copyWith(children: updated);
                    });
                  }
                },
                nodeBuilder: _buildNodeContents,
                theme: treeViewTheme,
              );
            },
          );
        }
        return Container();
      },
    );
  }

  Widget _buildNodeContents(BuildContext context, Node<GroupData> node) {
    TreeView<GroupData>? treeView = TreeView.of<GroupData>(context);
    assert(treeView != null, 'TreeView must exist in context');
    TreeViewTheme theme = treeView!.theme;
    bool isSelected = treeView.controller.selectedKey != null && treeView.controller.selectedKey == node.key;
    List<StatefulWidget> buttons = node.data!.uuid == _managedGroupUuid ? _buildButtons(node, isSelected) : [];
    return Container(
      padding: EdgeInsets.symmetric(vertical: theme.verticalSpacing ?? (theme.dense ? 10 : 15), horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text(
                  node.label,
                  softWrap: node.isParent ? theme.parentLabelOverflow == null : theme.labelOverflow == null,
                  overflow: node.isParent ? theme.parentLabelOverflow : theme.labelOverflow,
                  style: node.isParent
                      ? theme.parentLabelStyle.copyWith(
                          fontWeight: theme.parentLabelStyle.fontWeight,
                          color: isSelected ? theme.colorScheme.onPrimary : theme.parentLabelStyle.color,
                        )
                      : theme.labelStyle.copyWith(
                          fontWeight: theme.labelStyle.fontWeight,
                          color: isSelected ? theme.colorScheme.onPrimary : null,
                        ),
                ),
              ),
            ],
          ),
          Wrap(spacing: 16, runSpacing: 0, children: [...buttons]),
        ],
      ),
    );
  }

  List<StatefulWidget> _buildButtons(Node<GroupData> node, bool isSelected) {
    final data = node.data!;
    final uuid = data.uuid;
    final str = S.of(context);
    final buttons = [
      if (!data.isDeleted && !data.isRecycleBin)
        OutlinedButton(
          child: Text(str.newGroup.toUpperCase()),
          onPressed: () {
            _newGroup(uuid);
          },
        ),
      if (!data.isDeleted && data.isMovable)
        OutlinedButton(
          child: Text(str.tagRename.toUpperCase()),
          onPressed: () {
            _renameGroup(uuid, node.label);
          },
        ),
      if (data.isMovable)
        OpenContainer<bool>(
          key: ValueKey('move group to new group screen'),
          tappable: false,
          closedShape: RoundedRectangleBorder(),
          closedElevation: 0,
          closedColor: Colors.transparent,
          transitionType: ContainerTransitionType.fade,
          transitionDuration: const Duration(milliseconds: 300),
          openBuilder: (context, close) {
            return GroupMoveTreeWidget(initialSelectedUuid: uuid, title: str.chooseNewParentGroupForGroup(node.label));
          },
          onClosed: (bool? result) {
            setState(() {
              _managedGroupUuid = null;
            });
          },
          closedBuilder: (context, open) {
            return OutlinedButton(
              child: Text(str.move.toUpperCase()),
              onPressed: () {
                open();
              },
            );
          },
        ),
      if (data.isMovable && !data.isDeleted)
        OutlinedButton(
          child: Text(str.detDelEntry.toUpperCase()),
          onPressed: () {
            if (isSelected) {
              BlocProvider.of<FilterCubit>(context).changeGroup(null);
            }
            _deleteGroup(uuid, false);
          },
        ),
      if (data.isDeleted)
        OutlinedButton(
          child: Text(str.detDelEntryPerm.toUpperCase()),
          onPressed: () {
            if (isSelected) {
              BlocProvider.of<FilterCubit>(context).changeGroup(null);
            }
            _deleteGroup(uuid, true);
          },
        ),
      if (data.isDeleted)
        OpenContainer<bool>(
          key: ValueKey('restore group from bin screen'),
          tappable: false,
          closedShape: RoundedRectangleBorder(),
          closedElevation: 0,
          closedColor: Colors.transparent,
          transitionType: ContainerTransitionType.fade,
          transitionDuration: const Duration(milliseconds: 300),
          openBuilder: (context, close) {
            return GroupMoveTreeWidget(initialSelectedUuid: uuid, title: str.chooseRestoreGroup);
          },
          onClosed: (bool? result) {
            setState(() {
              _managedGroupUuid = null;
            });
          },
          closedBuilder: (context, open) {
            return OutlinedButton(
              child: Text(str.restore.toUpperCase()),
              onPressed: () {
                open();
              },
            );
          },
        ),
      if (data.isRecycleBin)
        OutlinedButton(
          child: Text(str.menuEmptyTrash.toUpperCase()),
          onPressed: () {
            _emptyTrash();
          },
        ),
    ];
    return buttons;
  }

  void _newGroup(String uuid) async {
    final str = S.of(context);
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    final newName = await SimplePromptDialog(title: str.newGroup, labelText: str.groupNameNewExplanation).show(context);
    if (newName != null && newName.isNotEmpty) {
      vaultCubit.createGroup(parent: uuid, name: newName);
      setState(() {
        _managedGroupUuid = null;
      });
    }
  }

  void _renameGroup(String uuid, String currentName) async {
    final str = S.of(context);
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    final newName = await SimplePromptDialog(
      title: str.tagRename,
      labelText: str.groupNameRenameExplanation,
      initialValue: currentName,
    ).show(context);
    if (newName != null && newName.isNotEmpty) {
      vaultCubit.renameGroup(groupUuid: uuid, name: newName);
      setState(() {
        _managedGroupUuid = null;
      });
    }
  }

  void _deleteGroup(String uuid, bool permanent) async {
    final str = S.of(context);
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    final confirmed = await ConfirmDialog(
      params: ConfirmDialogParams(
        positiveButtonText: permanent ? str.detDelEntryPerm : str.detDelEntry,
        negativeButtonText: str.alertCancel,
        content: permanent ? str.permanentlyDeleteGroupConfirm : str.deleteGroupConfirm,
      ),
    ).show(context);
    if (confirmed != null && confirmed) {
      vaultCubit.deleteGroup(groupUuid: uuid);
      setState(() {
        _managedGroupUuid = null;
      });
    }
  }

  void _emptyTrash() async {
    final str = S.of(context);
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    final confirmed = await ConfirmDialog(
      params: ConfirmDialogParams(
        positiveButtonText: str.detDelEntryPerm,
        negativeButtonText: str.alertCancel,
        content: str.menuEmptyTrashAlertBody,
        title: str.menuEmptyTrashAlert,
      ),
    ).show(context);
    if (confirmed != null && confirmed) {
      vaultCubit.emptyRecycleBin();
      setState(() {
        _managedGroupUuid = null;
      });
    }
  }
}
