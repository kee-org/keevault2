import 'package:bloc/bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:keevault/logging/logger.dart';
import 'package:keevault/model/password_generator_profile.dart';
import 'package:meta/meta.dart';
import 'package:collection/collection.dart';

part 'generator_profiles_state.dart';

class GeneratorProfilesCubit extends Cubit<GeneratorProfilesState> {
  factory GeneratorProfilesCubit() {
    final settings = PasswordGeneratorProfileSettings.fromStorage();
    final defaultProfile =
        (builtinPasswordGeneratorProfiles + settings.user).firstWhereOrNull(
          (profile) => profile.name == settings.defaultProfileName,
        ) ??
        defaultPasswordGeneratorProfile;
    return GeneratorProfilesCubit._(settings, defaultProfile);
  }

  GeneratorProfilesCubit._(PasswordGeneratorProfileSettings settings, PasswordGeneratorProfile defaultProfile)
    : super(GeneratorProfilesEnabled(settings, defaultProfile));

  void reloadFromSettings(PasswordGeneratorProfileSettings settings) {
    if (state is GeneratorProfilesCreating) {
      final currentState = state as GeneratorProfilesCreating;

      emit(
        GeneratorProfilesCreating(
          settings,
          currentState.enabled.any((enabled) => enabled.name == currentState.current.name)
              ? currentState.current
              : currentState.enabled.firstWhere(
                  (profile) => profile.name == currentState.profileSettings.defaultProfileName,
                ),
          currentState.newProfile,
        ),
      );
    } else {
      final currentState = state as GeneratorProfilesEnabled;
      emit(GeneratorProfilesEnabled(settings, currentState.current));
    }
  }

  Future<void> persistLatestSettings(PasswordGeneratorProfileSettings settings) async {
    await Settings.setValue('generatorPresets', settings.toJson());
    await Settings.setValue('embeddedConfigUpdatedAtGeneratorPresets', DateTime.now().toUtc().millisecondsSinceEpoch);
  }

  Future<void> renameProfile(String oldName, String requestedName) async {
    final currentState = state as GeneratorProfilesEnabled;
    String newName = requestedName;

    while (currentState.all.any((profile) => profile.name == newName)) {
      newName = '$newName (duplicate)';
    }
    final newProfile = currentState.profileSettings.user
        .firstWhereOrNull((profile) => profile.name == oldName)
        ?.copyWith(name: newName, title: newName);

    if (newProfile == null) {
      l.e('Invalid request to rename a profile ($oldName) not found in user list');
      return;
    }

    final disabled = currentState.profileSettings.disabled.where((profile) => profile != oldName).toList();
    if (disabled.length != currentState.profileSettings.disabled.length) {
      disabled.add(newName);
    }

    final newSettings = currentState.profileSettings.copyWith(
      user: [...currentState.profileSettings.user.where((profile) => profile.name != oldName), newProfile],
      disabled: disabled,
      defaultProfileName: currentState.profileSettings.defaultProfileName == oldName ? newName : null,
    );

    emit(GeneratorProfilesEnabled(newSettings, currentState.current));
    await persistLatestSettings(newSettings);
  }

  void startDefiningNewProfile() {
    if (state is GeneratorProfilesCreating) return;
    final currentState = state as GeneratorProfilesEnabled;
    emit(
      GeneratorProfilesCreating(
        currentState.profileSettings,
        currentState.current,
        PasswordGeneratorProfile.emptyTemplate(),
      ),
    );
  }

  void discardNewProfile() {
    if (state is! GeneratorProfilesCreating) return;
    final currentState = state as GeneratorProfilesCreating;
    emit(GeneratorProfilesEnabled(currentState.profileSettings, currentState.current));
  }

  Future<void> addNewProfile() async {
    if (state is! GeneratorProfilesCreating) return;
    final currentState = state as GeneratorProfilesCreating;
    String newName = currentState.newProfile.name;

    while (currentState.all.any((profile) => profile.name == newName)) {
      newName = '$newName (duplicate)';
    }

    final newSettings = currentState.profileSettings.copyWith(
      user: [
        ...currentState.profileSettings.user,
        currentState.newProfile.copyWith(name: newName, title: newName),
      ],
    );

    emit(GeneratorProfilesEnabled(newSettings, currentState.current));
    await persistLatestSettings(newSettings);
  }

  Future<void> removeProfile(String name) async {
    final currentState = state as GeneratorProfilesEnabled;
    var newUserProfiles = currentState.profileSettings.user.where((profile) => profile.name != name).toList();

    if (newUserProfiles.length == currentState.profileSettings.user.length) {
      l.e("We were asked to remove a profile ($name) that doesn't exist in the list of user profiles");
      return;
    }

    String newDefaultName = currentState.profileSettings.defaultProfileName;
    if (newDefaultName == name) {
      newDefaultName = determineNewDefaultProfileName(
        currentState.profileSettings.defaultProfileName,
        currentState.profileSettings.disabled,
        newUserProfiles,
      );
    }

    final newSettings = currentState.profileSettings.copyWith(
      defaultProfileName: newDefaultName,
      user: newUserProfiles,
      disabled: currentState.profileSettings.disabled.where((profile) => profile != name).toList(),
    );
    emit(
      GeneratorProfilesEnabled(
        newSettings,
        currentState.current.name == name
            ? currentState.enabled.firstWhere((profile) => profile.name == newDefaultName).copyWith()
            : currentState.current,
      ),
    );
    await persistLatestSettings(newSettings);
  }

  Future<void> setEnabledProfile(String name, bool enabled) async {
    final currentState = state as GeneratorProfilesEnabled;

    if (!enabled) {
      final disabledCount = currentState.profileSettings.disabled.length;
      final totalCount = currentState.profileSettings.user.length + PasswordGeneratorProfile.builtInNames.length;
      if (totalCount - disabledCount <= 1) {
        return;
      }
    }
    final newList = [...currentState.profileSettings.disabled.where((profile) => profile != name), if (!enabled) name];

    String newDefaultName = currentState.profileSettings.defaultProfileName;
    if (newList.contains(currentState.profileSettings.defaultProfileName)) {
      newDefaultName = determineNewDefaultProfileName(
        currentState.profileSettings.defaultProfileName,
        newList,
        currentState.profileSettings.user,
      );
    }

    final newSettings = currentState.profileSettings.copyWith(defaultProfileName: newDefaultName, disabled: newList);

    emit(
      GeneratorProfilesEnabled(
        newSettings,
        newList.contains(currentState.current.name)
            ? currentState.all.firstWhere((profile) => profile.name == newDefaultName)
            : currentState.current,
      ),
    );
    await persistLatestSettings(newSettings);
  }

  String determineNewDefaultProfileName(
    String currentDefaultProfileName,
    List<String> disabledNames,
    List<PasswordGeneratorProfile> userProfiles,
  ) {
    String? newDefaultName = currentDefaultProfileName;

    newDefaultName = null;
    for (var name in PasswordGeneratorProfile.builtInNames) {
      if (!disabledNames.contains(name)) {
        newDefaultName = name;
        break;
      }
    }
    if (newDefaultName == null) {
      for (var profile in userProfiles) {
        if (!disabledNames.contains(profile.name)) {
          newDefaultName = profile.name;
          break;
        }
      }
    }

    if (newDefaultName == null) {
      throw Exception('No suitable preset found for new default');
    }

    return newDefaultName;
  }

  Future<void> changeDefaultProfile(String name) async {
    final currentState = state as GeneratorProfilesEnabled;
    if (currentState.profileSettings.disabled.contains(name)) {
      l.w('Attempted to change default to a disabled preset');
      return;
    }
    final newSettings = currentState.profileSettings.copyWith(defaultProfileName: name);
    emit(GeneratorProfilesEnabled(newSettings, currentState.current));
    await persistLatestSettings(newSettings);
  }

  void changeLength(double length) {
    if (state is GeneratorProfilesCreating) {
      final currentState = state as GeneratorProfilesCreating;
      emit(
        GeneratorProfilesCreating(
          currentState.profileSettings,
          currentState.current,
          currentState.newProfile.copyWith(length: length.toInt()),
        ),
      );
    } else {
      final currentState = state as GeneratorProfilesEnabled;
      emit(
        GeneratorProfilesEnabled(currentState.profileSettings, currentState.current.copyWith(length: length.toInt())),
      );
    }
  }

  void changeName(String name) {
    if (state is GeneratorProfilesCreating) {
      final currentState = state as GeneratorProfilesCreating;
      emit(
        GeneratorProfilesCreating(
          currentState.profileSettings,
          currentState.current,
          currentState.newProfile.copyWith(name: name, title: name),
        ),
      );
    } else {
      final currentState = state as GeneratorProfilesEnabled;
      emit(
        GeneratorProfilesEnabled(currentState.profileSettings, currentState.current.copyWith(name: name, title: name)),
      );
    }
  }

  void toggleCharacterSet({
    bool? upper,
    bool? lower,
    bool? digits,
    bool? special,
    bool? brackets,
    bool? high,
    bool? ambiguous,
  }) {
    if (state is GeneratorProfilesCreating) {
      final currentState = state as GeneratorProfilesCreating;
      emit(
        GeneratorProfilesCreating(
          currentState.profileSettings,
          currentState.current,
          currentState.newProfile.copyWith(
            upper: upper,
            lower: lower,
            digits: digits,
            special: special,
            brackets: brackets,
            high: high,
            ambiguous: ambiguous,
          ),
        ),
      );
    } else {
      final currentState = state as GeneratorProfilesEnabled;
      emit(
        GeneratorProfilesEnabled(
          currentState.profileSettings,
          currentState.current.copyWith(
            upper: upper,
            lower: lower,
            digits: digits,
            special: special,
            brackets: brackets,
            high: high,
            ambiguous: ambiguous,
          ),
        ),
      );
    }
  }

  void changeAdditionalChars(String value) {
    if (state is GeneratorProfilesCreating) {
      final currentState = state as GeneratorProfilesCreating;
      emit(
        GeneratorProfilesCreating(
          currentState.profileSettings,
          currentState.current,
          currentState.newProfile.copyWith(include: value),
        ),
      );
    } else {
      final currentState = state as GeneratorProfilesEnabled;
      emit(GeneratorProfilesEnabled(currentState.profileSettings, currentState.current.copyWith(include: value)));
    }
  }

  GeneratorProfilesEnabled? changeCurrentProfile(String value) {
    final currentState = state as GeneratorProfilesEnabled;
    final profile = currentState.enabled.firstWhereOrNull((p) => p.name == value);
    if (profile == null) {
      l.e('Profile $value not found');
      return null;
    }
    final newProfile = GeneratorProfilesEnabled(currentState.profileSettings, profile.copyWith());
    emit(newProfile);
    return newProfile;
  }
}
