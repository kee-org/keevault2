import 'dart:math';

import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/config/app.dart';
import 'package:keevault/config/routes.dart';
import 'package:keevault/cubit/generator_profiles_cubit.dart';
import 'package:keevault/model/password_generator_profile.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import '../generated/l10n.dart';
import '../phonetic.dart';

S _str = S();

class PasswordGeneratorWidget extends StatefulWidget {
  final Function? apply;
  const PasswordGeneratorWidget({
    Key? key,
    this.apply,
  }) : super(key: key);

  @override
  State<PasswordGeneratorWidget> createState() => _PasswordGeneratorWidgetState();
}

class _PasswordGeneratorWidgetState extends State<PasswordGeneratorWidget> with TraceableClientMixin {
  @override
  String get traceTitle => widget.toStringShort();

  String _currentPassword = '';
  final TextEditingController _includeTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = BlocProvider.of<GeneratorProfilesCubit>(context).state;
    if (state is GeneratorProfilesEnabled) {
      _currentPassword = _generate(state.current);
      _includeTextController.text = state.current.include;
    }
  }

  String _generate(PasswordGeneratorProfile profile) {
    if (profile.name == 'Pronounceable') {
      return generatePronounceable(profile.length);
    } else if (profile.name == 'Mac') {
      return generateMac();
    }
    // Users may supply grapheme clusters that comprise of multiple runes. The expectation would
    //  be that each of these counts as 1 towards the desired length, and we must also beware of splitting
    // them into constituent runes and shuffling the result since this is likely to result in unprintable
    // and likely illogical user-perceived characters.
    // Because direct index access to the stream of grapheme clusters ("Characters")
    //  is not possible, we instead iterate through the list of candidates once and
    // then directly access the desired characters. Maybe we could find a way to populate
    // the relevant positions in the final password array when we first iterate to a selected
    //  position index which will make generating very long passwords a touch more efficient
    // but it probably won't be noticeable above the costs for random number generation anyway.

    final candidateCharacterSets = StringBuffer(profile.include);
    if (profile.ambiguous) candidateCharacterSets.write(PasswordGeneratorCharRanges.ambiguous);
    if (profile.brackets) candidateCharacterSets.write(PasswordGeneratorCharRanges.brackets);
    if (profile.digits) candidateCharacterSets.write(PasswordGeneratorCharRanges.digits);
    if (profile.lower) candidateCharacterSets.write(PasswordGeneratorCharRanges.lower);
    if (profile.upper) candidateCharacterSets.write(PasswordGeneratorCharRanges.upper);
    if (profile.high) candidateCharacterSets.write(PasswordGeneratorCharRanges.high);
    if (profile.special) candidateCharacterSets.write(PasswordGeneratorCharRanges.special);

    final candidateCharacters = candidateCharacterSets.toString().characters.toList(growable: false);
    if (candidateCharacters.isEmpty) {
      return '';
    }

    final selectedCharacters = <String>[];
    final randomness = Random.secure();

    for (var i = 0; i < profile.length; i++) {
      selectedCharacters.add(candidateCharacters[randomness.nextInt(candidateCharacters.length)]);
    }

    return selectedCharacters.join('');
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return BlocConsumer<GeneratorProfilesCubit, GeneratorProfilesState>(
      builder: (context, state) {
        final generatorState = state as GeneratorProfilesEnabled;
        return Scaffold(
          key: widget.key,
          appBar: AppBar(title: Text(str.createSecurePassword)),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(width: 2.0),
                      borderRadius: BorderRadius.all(Radius.circular(10.0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                          child: Text(
                        _currentPassword,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      )),
                    )),
              ),
              Expanded(
                child: SingleChildScrollView(
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
                            child: Text(
                                '${widget.apply != null ? str.createNewPasswordApplyExplanation : str.createNewPasswordCopyExplanation} ${str.createNewPasswordConfigurationExplanation}'),
                          ),
                          _profileChooser(context, generatorState),
                          lengthChooser(context, generatorState.current),
                          presetCharChooser(context, generatorState.current),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 64.0),
                            child: additionalCharIncludes(context, generatorState.current, _includeTextController),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            autofocus: true,
            icon: widget.apply != null ? Icon(Icons.check) : Icon(Icons.copy),
            label: widget.apply != null ? Text(str.apply.toUpperCase()) : Text(str.alertCopy.toUpperCase()),
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (widget.apply != null) {
                widget.apply!(_currentPassword);
              } else {
                await Clipboard.setData(ClipboardData(text: _currentPassword));
              }
              navigator.pop(true);
            },
          ),
        );
      },
      listener: (context, state) {
        if (state is! GeneratorProfilesEnabled) return;
        final generatorState = state;
        setState(() => {_currentPassword = _generate(generatorState.current)});
      },
    );
  }

  _profileChooser(BuildContext context, GeneratorProfilesEnabled generatorState) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Text(_str.preset),
          ),
          DropdownButton<String>(
            value: generatorState.current.name,
            items: <DropdownMenuItem<String>>[
              ...generatorState.enabled.map((p) => DropdownMenuItem(
                    value: p.name,
                    child: Text(p.title),
                  ))
            ],
            onChanged: (value) {
              if (value == null) return;
              final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
              final newProfile = cubit.changeCurrentProfile(value);
              if (newProfile != null) {
                _includeTextController.value = TextEditingValue(
                    text: newProfile.current.include,
                    selection: TextSelection.collapsed(offset: newProfile.current.include.length));
              }
            },
          ),
          OutlinedButton(
            onPressed: () async => await AppConfig.router.navigateTo(
              context,
              Routes.passwordPresetManager,
              transition: TransitionType.inFromRight,
            ),
            child: Text(_str.managePresets),
          )
        ],
      ),
    );
  }

  String generateMac() {
    final randomness = Random.secure();
    final output = <String>[];
    for (var i = 0; i < 6; i++) {
      output.add(randomness.nextInt(255).toRadixString(16).padLeft(2, '0'));
    }
    return output.join(':');
  }

  String generatePronounceable(int length) {
    //TODO:f: Split large strings into multiple "words" of random lengths between around 6 and 12 characters
    // final wordLengths = [];
    // int assignedLength = 0;
    // do {
    //   final nextLength = 6 + Random().nextInt(5);

    // } while (assignedLength < length - 6);
    return generate(Options(length: length, compoundSimplicity: 3, phoneticSimplicity: 3));
  }
}

Widget lengthChooser(BuildContext context, PasswordGeneratorProfile profile) {
  final str = S.of(context);
  return Visibility(
    visible: profile.supportsLengthChoosing,
    child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Row(
        children: <Widget>[
          Text(str.genLen),
          Expanded(
            child: Slider(
              value: profile.length.toDouble(),
              min: 4.0,
              max: 100.0,
              onChanged: (double value) {
                final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                cubit.changeLength(value);
              },
            ),
          ),
          Semantics(
            label: str.genLen,
            child: SizedBox(
              width: 48,
              height: 48,
              child: TextField(
                onSubmitted: (String value) {
                  final double? newValue = double.tryParse(value);
                  if (newValue != null && newValue != profile.length) {
                    final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
                    cubit.changeLength(newValue.clamp(4, 100));
                  }
                },
                keyboardType: TextInputType.number,
                controller: TextEditingController(
                  text: profile.length.toStringAsFixed(0),
                ),
              ),
            ),
          ),
        ],
      ),
    ]),
  );
}

Widget additionalCharIncludes(
    BuildContext context, PasswordGeneratorProfile profile, TextEditingController controller) {
  final str = S.of(context);
  return Visibility(
    visible: profile.supportsCharacterChoosing,
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Text(str.additionalCharacters),
        ),
        Expanded(
          child: TextField(
            onChanged: (String value) {
              final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
              cubit.changeAdditionalChars(value);
            },
            keyboardType: TextInputType.text,
            controller: controller,
          ),
        ),
      ],
    ),
  );
}

Widget presetCharChooser(BuildContext context, PasswordGeneratorProfile profile) {
  return Visibility(
    visible: profile.supportsCharacterChoosing,
    child: Container(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 6.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 0.0,
        children: [
          FilterChip(
            visualDensity: VisualDensity.compact,
            label: Text(_str.genPsUpper),
            avatar: profile.upper
                ? Icon(
                    Icons.check,
                    size: 18,
                  )
                : SizedBox(width: 24),
            labelPadding: EdgeInsets.only(left: 2, right: 12),
            showCheckmark: false,
            selected: profile.upper,
            onSelected: (bool value) => _toggleCharChooser(context, upper: value),
            tooltip: PasswordGeneratorCharRanges.upper,
          ),
          FilterChip(
            visualDensity: VisualDensity.compact,
            label: Text(_str.genPsLower),
            avatar: profile.lower
                ? Icon(
                    Icons.check,
                    size: 18,
                  )
                : SizedBox(width: 24),
            labelPadding: EdgeInsets.only(left: 2, right: 12),
            showCheckmark: false,
            selected: profile.lower,
            onSelected: (bool value) => _toggleCharChooser(context, lower: value),
            tooltip: PasswordGeneratorCharRanges.lower,
          ),
          FilterChip(
            visualDensity: VisualDensity.compact,
            label: Text(_str.genPsDigits),
            avatar: profile.digits
                ? Icon(
                    Icons.check,
                    size: 18,
                  )
                : SizedBox(width: 24),
            labelPadding: EdgeInsets.only(left: 2, right: 12),
            showCheckmark: false,
            selected: profile.digits,
            onSelected: (bool value) => _toggleCharChooser(context, digits: value),
            tooltip: PasswordGeneratorCharRanges.digits,
          ),
          FilterChip(
            visualDensity: VisualDensity.compact,
            label: Text(_str.genPsSpecial),
            avatar: profile.special
                ? Icon(
                    Icons.check,
                    size: 18,
                  )
                : SizedBox(width: 24),
            labelPadding: EdgeInsets.only(left: 2, right: 12),
            showCheckmark: false,
            selected: profile.special,
            onSelected: (bool value) => _toggleCharChooser(context, special: value),
            tooltip: PasswordGeneratorCharRanges.special,
          ),
          FilterChip(
            visualDensity: VisualDensity.compact,
            label: Text(_str.genPsBrackets),
            avatar: profile.brackets
                ? Icon(
                    Icons.check,
                    size: 18,
                  )
                : SizedBox(width: 24),
            labelPadding: EdgeInsets.only(left: 2, right: 12),
            showCheckmark: false,
            selected: profile.brackets,
            onSelected: (bool value) => _toggleCharChooser(context, brackets: value),
            tooltip: PasswordGeneratorCharRanges.brackets,
          ),
          FilterChip(
            visualDensity: VisualDensity.compact,
            label: Text(_str.genPsHigh),
            avatar: profile.high
                ? Icon(
                    Icons.check,
                    size: 18,
                  )
                : SizedBox(width: 24),
            labelPadding: EdgeInsets.only(left: 2, right: 12),
            showCheckmark: false,
            selected: profile.high,
            onSelected: (bool value) => _toggleCharChooser(context, high: value),
            tooltip: PasswordGeneratorCharRanges.high,
          ),
          FilterChip(
            visualDensity: VisualDensity.compact,
            label: Text(_str.genPsAmbiguous),
            avatar: profile.ambiguous
                ? Icon(
                    Icons.check,
                    size: 18,
                  )
                : SizedBox(width: 24),
            labelPadding: EdgeInsets.only(left: 2, right: 12),
            showCheckmark: false,
            selected: profile.ambiguous,
            onSelected: (bool value) => _toggleCharChooser(context, ambiguous: value),
            tooltip: PasswordGeneratorCharRanges.ambiguous,
          ),
        ],
      ),
    ),
  );
}

void _toggleCharChooser(
  BuildContext context, {
  bool? upper,
  bool? lower,
  bool? digits,
  bool? special,
  bool? brackets,
  bool? high,
  bool? ambiguous,
}) {
  final cubit = BlocProvider.of<GeneratorProfilesCubit>(context);
  cubit.toggleCharacterSet(
    upper: upper,
    lower: lower,
    digits: digits,
    special: special,
    brackets: brackets,
    high: high,
    ambiguous: ambiguous,
  );
}
