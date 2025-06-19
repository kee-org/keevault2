import 'package:animations/animations.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/config/app.dart';
import 'package:keevault/cubit/generator_profiles_cubit.dart';
import 'package:keevault/model/password_generator_profile.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import '../generated/l10n.dart';
import 'coloured_safe_area_widget.dart';
import 'dialog_utils.dart';
import 'password_generator.dart';

S _str = S();

class PasswordPresetManagerWidget extends StatefulWidget {
  final Function? apply;
  const PasswordPresetManagerWidget({super.key, this.apply});

  @override
  State<PasswordPresetManagerWidget> createState() => _PasswordPresetManagerWidgetState();
}

class _PasswordPresetManagerWidgetState extends State<PasswordPresetManagerWidget> with TraceableClientMixin {
  @override
  String get actionName => widget.toStringShort();

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
        return ColouredSafeArea(
          child: Scaffold(
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
                                child: Text(generatorState.all[index].title, style: theme.textTheme.titleMedium),
                              ),
                              subtitle: Text(
                                describeProfile(context, generatorState.all[index]),
                                style: theme.textTheme.titleSmall,
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
                                      value: !generatorState.profileSettings.disabled.contains(
                                        generatorState.all[index].name,
                                      ),
                                      onChanged: (bool? value) async {
                                        if (value != null) {
                                          final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                                          await cubit.setEnabledProfile(generatorState.all[index].name, value);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Visibility(
                                    visible:
                                        generatorState.profileSettings.defaultProfileName ==
                                        generatorState.all[index].name,
                                    replacement: Visibility(
                                      visible: !generatorState.profileSettings.disabled.contains(
                                        generatorState.all[index].name,
                                      ),
                                      child: OutlinedButton(
                                        child: Text(str.setDefault),
                                        onPressed: () async {
                                          final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                                          await cubit.changeDefaultProfile(generatorState.all[index].name);
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
                              child: OverflowBar(
                                alignment: MainAxisAlignment.start,
                                spacing: 8.0,
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
                                        await cubit.renameProfile(generatorState.all[index].name, newName);
                                      }
                                    },
                                    child: Text(str.tagRename.toUpperCase()),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                                      await cubit.removeProfile(generatorState.all[index].name);
                                    },
                                    child: Text(str.genPsDelete.toUpperCase()),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
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
                    return ColouredSafeArea(
                      child: Scaffold(
                        appBar: AppBar(title: Text(str.newProfile)),
                        body: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SafeArea(
                              top: false,
                              left: false,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: TextFormField(
                                      onChanged: (String value) {
                                        final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                                        cubit.changeName(value);
                                      },
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(),
                                        labelText: str.name.capitalize,
                                      ),
                                    ),
                                  ),
                                  lengthChooser(context, generatorState.newProfile),
                                  presetCharChooser(context, generatorState.newProfile),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 64.0),
                                    child: additionalCharIncludes(
                                      context,
                                      generatorState.newProfile,
                                      _includeTextController,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        extendBody: true,
                        bottomNavigationBar: Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              OutlinedButton(
                                child: Text(str.alertCancel.toUpperCase()),
                                onPressed: () {
                                  final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                                  cubit.discardNewProfile();
                                  Navigator.of(AppConfig.navigatorKey.currentContext!).pop(true);
                                },
                              ),
                              FilledButton(
                                onPressed: generatorState.newProfile.name.isNotEmpty
                                    ? () async {
                                        final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                                        await cubit.addNewProfile();
                                        Navigator.of(AppConfig.navigatorKey.currentContext!).pop(true);
                                      }
                                    : null,
                                child: Text(str.add.toUpperCase()),
                              ),
                            ],
                          ),
                        ),
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
          ),
        );
      },
    );
  }
}
