part of 'autofill_cubit.dart';

@immutable
abstract class AutofillState {}

class AutofillInitial extends AutofillState {}

class AutofillMissing extends AutofillState {}

class AutofillAvailable extends AutofillState {
  final bool enabled;

  AutofillAvailable(this.enabled);
}

class AutofillModeActive extends AutofillAvailable {
  final AutofillMetadata androidMetadata;
  AutofillModeActive(this.androidMetadata) : super(true);
}

class AutofillRequested extends AutofillModeActive {
  final AutofillTarget target;

  /// null until the vault is open
  final AutofillMatches? matches;

  /// The user's choice to also link an unverified website to the entry they pick (only offered inside a verified app)
  final bool linkUnverifiedDomain;

  AutofillRequested(this.target, AutofillMetadata androidMetadata, {this.matches, this.linkUnverifiedDomain = false})
    : super(androidMetadata);

  AutofillRequested copyWith({AutofillMatches? matches, bool? linkUnverifiedDomain}) => AutofillRequested(
    target,
    androidMetadata,
    matches: matches ?? this.matches,
    linkUnverifiedDomain: linkUnverifiedDomain ?? this.linkUnverifiedDomain,
  );
}

class AutofillSaving extends AutofillModeActive {
  AutofillSaving(super.androidMetadata);
}

class AutofillSaved extends AutofillModeActive {
  AutofillSaved(super.androidMetadata);
}
