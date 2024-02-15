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
  final bool forceInteractive;
  AutofillRequested(this.forceInteractive, AutofillMetadata androidMetadata) : super(androidMetadata);
}

class AutofillSaving extends AutofillModeActive {
  AutofillSaving(super.androidMetadata);
}

class AutofillSaved extends AutofillModeActive {
  AutofillSaved(super.androidMetadata);
}
