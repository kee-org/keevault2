import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/cubit/generator_profiles_cubit.dart';
import 'package:keevault/model/password_generator_profile.dart';
import 'package:matomo/matomo.dart';
import '../generated/l10n.dart';
import 'dialog_utils.dart';
import 'password_generator.dart';

S _str = S();

class PasswordPresetManagerWidget extends TraceableStatefulWidget {
  final Function? apply;
  const PasswordPresetManagerWidget({
    Key? key,
    this.apply,
  }) : super(key: key);

  @override
  State<PasswordPresetManagerWidget> createState() => _PasswordPresetManagerWidgetState();
}

class _PasswordPresetManagerWidgetState extends State<PasswordPresetManagerWidget> {
  final TextEditingController _includeTextController = TextEditingController();

  String describeProfile(BuildContext context, PasswordGeneratorProfile profile) {
    final str = S.of(context);
    final includes = [
      if (profile.upper) str.genPsUpper,
      if (profile.lower) str.genPsLower,
      if (profile.digits) str.genPsDigits,
      if (profile.special) str.genPsSpecial,
      if (profile.brackets) str.genPsBrackets,
      if (profile.high) str.genPsHigh,
      if (profile.ambiguous) str.genPsAmbiguous,
      if (profile.include.isNotEmpty) '${str.additionalCharacters}: ${profile.include}',
    ].join(', ');
    return 'Length: ${profile.length}. Includes: $includes';
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<GeneratorProfilesCubit, GeneratorProfilesState>(
      builder: (context, state) {
        final generatorState = state as GeneratorProfilesEnabled;
        return Scaffold(
          key: widget.key,
          appBar: AppBar(title: Text(_str.managePasswordPresets)),
          body: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: generatorState.all.length,
              itemBuilder: (BuildContext context, int index) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              title: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  generatorState.all[index].title,
                                  style: theme.textTheme.subtitle1,
                                ),
                              ),
                              subtitle: Text(
                                describeProfile(context, generatorState.all[index]),
                                style: theme.textTheme.subtitle2,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: ListTile(
                                    title: Text(str.enabled),
                                    leading: Switch(
                                      value: !generatorState.profileSettings.disabled
                                          .contains(generatorState.all[index].name),
                                      onChanged: (bool? value) {
                                        if (value != null) {
                                          final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                                          cubit.setEnabledProfile(generatorState.all[index].name, value);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Visibility(
                                    visible: generatorState.profileSettings.defaultProfileName ==
                                        generatorState.all[index].name,
                                    replacement: Visibility(
                                      visible: !generatorState.profileSettings.disabled
                                          .contains(generatorState.all[index].name),
                                      child: OutlinedButton(
                                        child: Text(str.setDefault),
                                        onPressed: () {
                                          final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                                          cubit.changeDefaultProfile(generatorState.all[index].name);
                                        },
                                      ),
                                    ),
                                    child: Text(str.genPsDefault),
                                  ),
                                ),
                              ],
                            ),
                            Visibility(
                              visible: generatorState.all[index].isUserDefined,
                              child: ButtonBar(
                                alignment: MainAxisAlignment.start,
                                children: [
                                  TextButton(
                                    onPressed: () async {
                                      final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                                      final newName = await SimplePromptDialog(
                                        title: str.renamingPreset,
                                        labelText: str.enterNewPresetName,
                                        initialValue: generatorState.all[index].name,
                                      ).show(context);
                                      if (newName != null) {
                                        cubit.renameProfile(generatorState.all[index].name, newName);
                                      }
                                    },
                                    child: Text(str.tagRename.toUpperCase()),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                                      cubit.removeProfile(generatorState.all[index].name);
                                    },
                                    child: Text(str.genPsDelete.toUpperCase()),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
          floatingActionButton: OpenContainer<bool>(
            key: ValueKey('new password generator profile screen'),
            tappable: false,
            closedShape: CircleBorder(),
            closedElevation: 0,
            closedColor: Colors.transparent,
            transitionType: ContainerTransitionType.fade,
            transitionDuration: const Duration(milliseconds: 300),
            openBuilder: (context, close) {
              return BlocBuilder<GeneratorProfilesCubit, GeneratorProfilesState>(
                builder: (context, state) {
                  final generatorState = state as GeneratorProfilesCreating;
                  return Scaffold(
                    appBar: AppBar(
                      title: Text(str.newProfile),
                    ),
                    body: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SafeArea(
                          top: false,
                          left: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              TextFormField(
                                onChanged: (String value) {
                                  final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                                  cubit.changeName(value);
                                },
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: str.name.toUpperCase(),
                                ),
                              ),
                              lengthChooser(context, generatorState.newProfile),
                              presetCharChooser(context, generatorState.newProfile),
                              additionalCharIncludes(context, generatorState.newProfile, _includeTextController),
                            ],
                          ),
                        ),
                      ),
                    ),
                    extendBody: true,
                    bottomNavigationBar: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton(
                            child: Text(str.alertCancel.toUpperCase()),
                            onPressed: () {
                              // Potential loss of context here but I think because the generator profiles cubit emit
                              // is the last thing to happen in the discardNewProfile task Flutter won't have had a
                              // chance to draw a new frame and detach this defunct widget from the context. If WTFs
                              // happen around here though, this is a strong candidate for the cause of the problem.
                              final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                              cubit.discardNewProfile();
                              Navigator.of(context).pop(true);
                            }),
                        OutlinedButton(
                            child: Text(str.add.toUpperCase()),
                            onPressed: () async {
                              // Potential loss of context here as per above comment
                              final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                              cubit.addNewProfile();
                              Navigator.of(context).pop(true);
                            }),
                      ],
                    ),
                  );
                },
                // Skip rebuilding while we are animating away during close dialog operation
                buildWhen: (previous, current) => current is GeneratorProfilesCreating,
              );
            },
            onClosed: (bool? wasCleanClose) {
              if (wasCleanClose == null || !wasCleanClose) {
                final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                cubit.discardNewProfile();
              }
            },
            closedBuilder: (context, open) {
              return FloatingActionButton(
                child: Icon(Icons.add),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                  cubit.startDefiningNewProfile();
                  open();
                },
              );
            },
          ),
        );
      },
    );
  }
}
