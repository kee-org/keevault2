part of 'generator_profiles_cubit.dart';

@immutable
abstract class GeneratorProfilesState {}

class GeneratorProfilesEnabled extends GeneratorProfilesState {
  final PasswordGeneratorProfileSettings profileSettings;
  final PasswordGeneratorProfile current;

  GeneratorProfilesEnabled(this.profileSettings, this.current);

  List<PasswordGeneratorProfile> get all {
    return builtinPasswordGeneratorProfiles + profileSettings.user;
  }

  List<PasswordGeneratorProfile> get enabled {
    final enabledProfiles = all.where((p) => !profileSettings.disabled.contains(p.name)).toList();
    if (enabledProfiles.isEmpty) {
      enabledProfiles.add(defaultPasswordGeneratorProfile);
    }
    return enabledProfiles;
  }
}

class GeneratorProfilesCreating extends GeneratorProfilesEnabled {
  final PasswordGeneratorProfile newProfile;
  GeneratorProfilesCreating(super.profileSettings, super.current, this.newProfile);
}
