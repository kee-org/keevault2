// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(_current != null,
        'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.');
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(instance != null,
        'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?');
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Loading`
  String get loading {
    return Intl.message(
      'Loading',
      name: 'loading',
      desc: '',
      args: [],
    );
  }

  /// `Downloading`
  String get downloading {
    return Intl.message(
      'Downloading',
      name: 'downloading',
      desc: '',
      args: [],
    );
  }

  /// `Opening`
  String get opening {
    return Intl.message(
      'Opening',
      name: 'opening',
      desc: '',
      args: [],
    );
  }

  /// `Merging`
  String get merging {
    return Intl.message(
      'Merging',
      name: 'merging',
      desc: '',
      args: [],
    );
  }

  /// `Identifying`
  String get identifying {
    return Intl.message(
      'Identifying',
      name: 'identifying',
      desc: '',
      args: [],
    );
  }

  /// `Authenticating`
  String get authenticating {
    return Intl.message(
      'Authenticating',
      name: 'authenticating',
      desc: '',
      args: [],
    );
  }

  /// `Welcome {email}`
  String welcome_message(Object email) {
    return Intl.message(
      'Welcome $email',
      name: 'welcome_message',
      desc: '',
      args: [email],
    );
  }

  /// `Enter your email address`
  String get enter_your_email_address {
    return Intl.message(
      'Enter your email address',
      name: 'enter_your_email_address',
      desc: '',
      args: [],
    );
  }

  /// `Enter your account password`
  String get enter_your_account_password {
    return Intl.message(
      'Enter your account password',
      name: 'enter_your_account_password',
      desc: '',
      args: [],
    );
  }

  /// `Email`
  String get email {
    return Intl.message(
      'Email',
      name: 'email',
      desc: '',
      args: [],
    );
  }

  /// `Password`
  String get password {
    return Intl.message(
      'Password',
      name: 'password',
      desc: '',
      args: [],
    );
  }

  /// `This field is required`
  String get this_field_required {
    return Intl.message(
      'This field is required',
      name: 'this_field_required',
      desc: '',
      args: [],
    );
  }

  /// `Unlock`
  String get unlock {
    return Intl.message(
      'Unlock',
      name: 'unlock',
      desc: '',
      args: [],
    );
  }

  /// `Save`
  String get save {
    return Intl.message(
      'Save',
      name: 'save',
      desc: '',
      args: [],
    );
  }

  /// `Lock`
  String get lock {
    return Intl.message(
      'Lock',
      name: 'lock',
      desc: '',
      args: [],
    );
  }

  /// `OTP`
  String get otp {
    return Intl.message(
      'OTP',
      name: 'otp',
      desc: '',
      args: [],
    );
  }

  /// `Showing all entries`
  String get showing_all_entries {
    return Intl.message(
      'Showing all entries',
      name: 'showing_all_entries',
      desc: '',
      args: [],
    );
  }

  /// `Unexpected error. Sorry! Please let us know, then close and restart the app. Details: {error}`
  String unexpected_error(Object error) {
    return Intl.message(
      'Unexpected error. Sorry! Please let us know, then close and restart the app. Details: $error',
      name: 'unexpected_error',
      desc: '',
      args: [error],
    );
  }

  /// `Use biometrics`
  String get unlock_with_biometrics {
    return Intl.message(
      'Use biometrics',
      name: 'unlock_with_biometrics',
      desc: '',
      args: [],
    );
  }

  /// `Do you want to keep your changes?`
  String get keep_your_changes_question {
    return Intl.message(
      'Do you want to keep your changes?',
      name: 'keep_your_changes_question',
      desc: '',
      args: [],
    );
  }

  /// `Discard`
  String get discard {
    return Intl.message(
      'Discard',
      name: 'discard',
      desc: '',
      args: [],
    );
  }

  /// `Keep`
  String get keep {
    return Intl.message(
      'Keep',
      name: 'keep',
      desc: '',
      args: [],
    );
  }

  /// `Colour`
  String get color {
    return Intl.message(
      'Colour',
      name: 'color',
      desc: '',
      args: [],
    );
  }

  /// `Title`
  String get sortTitle {
    return Intl.message(
      'Title',
      name: 'sortTitle',
      desc: '',
      args: [],
    );
  }

  /// `Title - reversed`
  String get sortTitleReversed {
    return Intl.message(
      'Title - reversed',
      name: 'sortTitleReversed',
      desc: '',
      args: [],
    );
  }

  /// `Recently updated`
  String get sortModified {
    return Intl.message(
      'Recently updated',
      name: 'sortModified',
      desc: '',
      args: [],
    );
  }

  /// `Least recently updated`
  String get sortModifiedReversed {
    return Intl.message(
      'Least recently updated',
      name: 'sortModifiedReversed',
      desc: '',
      args: [],
    );
  }

  /// `Newest`
  String get sortCreated {
    return Intl.message(
      'Newest',
      name: 'sortCreated',
      desc: '',
      args: [],
    );
  }

  /// `Oldest`
  String get sortCreatedReversed {
    return Intl.message(
      'Oldest',
      name: 'sortCreatedReversed',
      desc: '',
      args: [],
    );
  }

  /// `Manage your Kee Vault account`
  String get manageAccountDetail {
    return Intl.message(
      'Manage your Kee Vault account',
      name: 'manageAccountDetail',
      desc: '',
      args: [],
    );
  }

  /// `Manage account`
  String get manageAccount {
    return Intl.message(
      'Manage account',
      name: 'manageAccount',
      desc: '',
      args: [],
    );
  }

  /// `Biometric sign-in`
  String get biometricSignIn {
    return Intl.message(
      'Biometric sign-in',
      name: 'biometricSignIn',
      desc: '',
      args: [],
    );
  }

  /// `You must change your device's Autofill provider to {appName}.`
  String enableAutofillRequired(Object appName) {
    return Intl.message(
      'You must change your device\'s Autofill provider to $appName.',
      name: 'enableAutofillRequired',
      desc: '',
      args: [appName],
    );
  }

  /// `Kee Vault is correctly set as your device's Autofill provider.`
  String get autofillEnabled {
    return Intl.message(
      'Kee Vault is correctly set as your device\'s Autofill provider.',
      name: 'autofillEnabled',
      desc: '',
      args: [],
    );
  }

  /// `Enable Autofill`
  String get enableAutofill {
    return Intl.message(
      'Enable Autofill',
      name: 'enableAutofill',
      desc: '',
      args: [],
    );
  }

  /// `You can change your account password and some additional settings from the Kee Vault web app by using your web browser to sign in to Kee Vault.`
  String get useWebAppForOtherSettings {
    return Intl.message(
      'You can change your account password and some additional settings from the Kee Vault web app by using your web browser to sign in to Kee Vault.',
      name: 'useWebAppForOtherSettings',
      desc: '',
      args: [],
    );
  }

  /// `Open Kee Vault in your browser`
  String get openWebApp {
    return Intl.message(
      'Open Kee Vault in your browser',
      name: 'openWebApp',
      desc: '',
      args: [],
    );
  }

  /// `Edit your subscription, payment details or email contact preferences from the Kee Vault Account website.`
  String get manageAccountSettingsDetail {
    return Intl.message(
      'Edit your subscription, payment details or email contact preferences from the Kee Vault Account website.',
      name: 'manageAccountSettingsDetail',
      desc: '',
      args: [],
    );
  }

  /// `Device Settings`
  String get deviceSettings {
    return Intl.message(
      'Device Settings',
      name: 'deviceSettings',
      desc: '',
      args: [],
    );
  }

  /// `Integration settings`
  String get integrationSettings {
    return Intl.message(
      'Integration settings',
      name: 'integrationSettings',
      desc: '',
      args: [],
    );
  }

  /// `These settings help you to refine when this entry is autofilled into other apps and websites. Some settings apply only to when you use Kee on a desktop computer and others only to specific mobile platforms (such as Android, or iOS).`
  String get integrationSettingsExplainer {
    return Intl.message(
      'These settings help you to refine when this entry is autofilled into other apps and websites. Some settings apply only to when you use Kee on a desktop computer and others only to specific mobile platforms (such as Android, or iOS).',
      name: 'integrationSettingsExplainer',
      desc: '',
      args: [],
    );
  }

  /// `Additional URLs to match`
  String get additionalUrlsToMatch {
    return Intl.message(
      'Additional URLs to match',
      name: 'additionalUrlsToMatch',
      desc: '',
      args: [],
    );
  }

  /// `Android app technical names to match`
  String get androidAppIdsToMatch {
    return Intl.message(
      'Android app technical names to match',
      name: 'androidAppIdsToMatch',
      desc: '',
      args: [],
    );
  }

  /// `Show this entry in Kee browser extension (desktop), mobile apps and browsers`
  String get showEntryInBrowsersAndApps {
    return Intl.message(
      'Show this entry in Kee browser extension (desktop), mobile apps and browsers',
      name: 'showEntryInBrowsersAndApps',
      desc: '',
      args: [],
    );
  }

  /// `If you select Exact (for use on desktop web browsers) we'll use Hostname matching on mobile instead because Android and iOS do not permit Exact matching.`
  String get minURLMatchAccuracyExactWarning {
    return Intl.message(
      'If you select Exact (for use on desktop web browsers) we\'ll use Hostname matching on mobile instead because Android and iOS do not permit Exact matching.',
      name: 'minURLMatchAccuracyExactWarning',
      desc: '',
      args: [],
    );
  }

  /// `Add`
  String get add {
    return Intl.message(
      'Add',
      name: 'add',
      desc: '',
      args: [],
    );
  }

  /// `The URL only needs to be part of the same domain to match.`
  String get minimumMatchAccuracyDomainExplainer {
    return Intl.message(
      'The URL only needs to be part of the same domain to match.',
      name: 'minimumMatchAccuracyDomainExplainer',
      desc: '',
      args: [],
    );
  }

  /// `The URL must match the hostname (domain and subdomains) and port.`
  String get minimumMatchAccuracyHostnameExplainer {
    return Intl.message(
      'The URL must match the hostname (domain and subdomains) and port.',
      name: 'minimumMatchAccuracyHostnameExplainer',
      desc: '',
      args: [],
    );
  }

  /// `The URL must match exactly including full path and query string.`
  String get minimumMatchAccuracyExactExplainer {
    return Intl.message(
      'The URL must match exactly including full path and query string.',
      name: 'minimumMatchAccuracyExactExplainer',
      desc: '',
      args: [],
    );
  }

  /// `Set as default`
  String get setDefault {
    return Intl.message(
      'Set as default',
      name: 'setDefault',
      desc: '',
      args: [],
    );
  }

  /// `Additional characters`
  String get additionalCharacters {
    return Intl.message(
      'Additional characters',
      name: 'additionalCharacters',
      desc: '',
      args: [],
    );
  }

  /// `Preset`
  String get preset {
    return Intl.message(
      'Preset',
      name: 'preset',
      desc: '',
      args: [],
    );
  }

  /// `Manage presets`
  String get managePresets {
    return Intl.message(
      'Manage presets',
      name: 'managePresets',
      desc: '',
      args: [],
    );
  }

  /// `Manage password presets`
  String get managePasswordPresets {
    return Intl.message(
      'Manage password presets',
      name: 'managePasswordPresets',
      desc: '',
      args: [],
    );
  }

  /// `Move`
  String get move {
    return Intl.message(
      'Move',
      name: 'move',
      desc: '',
      args: [],
    );
  }

  /// `New Group`
  String get newGroup {
    return Intl.message(
      'New Group',
      name: 'newGroup',
      desc: '',
      args: [],
    );
  }

  /// `Long-press on a group to rename, move or delete it, or to create a new subgroup.`
  String get longPressGroupExplanation {
    return Intl.message(
      'Long-press on a group to rename, move or delete it, or to create a new subgroup.',
      name: 'longPressGroupExplanation',
      desc: '',
      args: [],
    );
  }

  /// `Restore`
  String get restore {
    return Intl.message(
      'Restore',
      name: 'restore',
      desc: '',
      args: [],
    );
  }

  /// `Enter the new name for the group`
  String get groupNameRenameExplanation {
    return Intl.message(
      'Enter the new name for the group',
      name: 'groupNameRenameExplanation',
      desc: '',
      args: [],
    );
  }

  /// `Enter the name for the new group`
  String get groupNameNewExplanation {
    return Intl.message(
      'Enter the name for the new group',
      name: 'groupNameNewExplanation',
      desc: '',
      args: [],
    );
  }

  /// `Delete the group and all entries within it?`
  String get deleteGroupConfirm {
    return Intl.message(
      'Delete the group and all entries within it?',
      name: 'deleteGroupConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Permanently delete the group and all entries within it?`
  String get permanentlyDeleteGroupConfirm {
    return Intl.message(
      'Permanently delete the group and all entries within it?',
      name: 'permanentlyDeleteGroupConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Select the new parent for the "{name}" group`
  String chooseNewParentGroupForGroup(Object name) {
    return Intl.message(
      'Select the new parent for the "$name" group',
      name: 'chooseNewParentGroupForGroup',
      desc: '',
      args: [name],
    );
  }

  /// `Select the group for this entry`
  String get chooseNewParentGroupForEntry {
    return Intl.message(
      'Select the group for this entry',
      name: 'chooseNewParentGroupForEntry',
      desc: '',
      args: [],
    );
  }

  /// `Select the group in which to restore this item`
  String get chooseRestoreGroup {
    return Intl.message(
      'Select the group in which to restore this item',
      name: 'chooseRestoreGroup',
      desc: '',
      args: [],
    );
  }

  /// `Labels allow you to categorise your entries.`
  String get labelsExplanation {
    return Intl.message(
      'Labels allow you to categorise your entries.',
      name: 'labelsExplanation',
      desc: '',
      args: [],
    );
  }

  /// `Unlike Groups, each entry can be assigned more than one label.`
  String get labelsExplanation2 {
    return Intl.message(
      'Unlike Groups, each entry can be assigned more than one label.',
      name: 'labelsExplanation2',
      desc: '',
      args: [],
    );
  }

  /// `Add new or existing labels to entries by editing the entry.`
  String get labelAssignmentExplanation {
    return Intl.message(
      'Add new or existing labels to entries by editing the entry.',
      name: 'labelAssignmentExplanation',
      desc: '',
      args: [],
    );
  }

  /// `Select labels above to display only entries with a matching label.`
  String get labelFilteringHint {
    return Intl.message(
      'Select labels above to display only entries with a matching label.',
      name: 'labelFilteringHint',
      desc: '',
      args: [],
    );
  }

  /// `Label`
  String get label {
    return Intl.message(
      'Label',
      name: 'label',
      desc: '',
      args: [],
    );
  }

  /// `Labels`
  String get labels {
    return Intl.message(
      'Labels',
      name: 'labels',
      desc: '',
      args: [],
    );
  }

  /// `Colours allow you to categorise your entries in a more simplistic and visual way than Groups or Labels.`
  String get colorsExplanation {
    return Intl.message(
      'Colours allow you to categorise your entries in a more simplistic and visual way than Groups or Labels.',
      name: 'colorsExplanation',
      desc: '',
      args: [],
    );
  }

  /// `Select colours above to display only entries with a matching colour.`
  String get colorFilteringHint {
    return Intl.message(
      'Select colours above to display only entries with a matching colour.',
      name: 'colorFilteringHint',
      desc: '',
      args: [],
    );
  }

  /// `These options change how Search uses your text input to find entries.`
  String get textFilteringHint {
    return Intl.message(
      'These options change how Search uses your text input to find entries.',
      name: 'textFilteringHint',
      desc: '',
      args: [],
    );
  }

  /// `Search in these entry fields:`
  String get searchSearchIn {
    return Intl.message(
      'Search in these entry fields:',
      name: 'searchSearchIn',
      desc: '',
      args: [],
    );
  }

  /// `Other standard fields`
  String get searchOtherStandard {
    return Intl.message(
      'Other standard fields',
      name: 'searchOtherStandard',
      desc: '',
      args: [],
    );
  }

  /// `Other protected fields`
  String get searchOtherSecure {
    return Intl.message(
      'Other protected fields',
      name: 'searchOtherSecure',
      desc: '',
      args: [],
    );
  }

  /// `Notes`
  String get notes {
    return Intl.message(
      'Notes',
      name: 'notes',
      desc: '',
      args: [],
    );
  }

  /// `Website`
  String get website {
    return Intl.message(
      'Website',
      name: 'website',
      desc: '',
      args: [],
    );
  }

  /// `Include entry history`
  String get searchHistory {
    return Intl.message(
      'Include entry history',
      name: 'searchHistory',
      desc: '',
      args: [],
    );
  }

  /// `Colours`
  String get colors {
    return Intl.message(
      'Colours',
      name: 'colors',
      desc: '',
      args: [],
    );
  }

  /// `Filtered by {criteria}`
  String filteredByCriteria(Object criteria) {
    return Intl.message(
      'Filtered by $criteria',
      name: 'filteredByCriteria',
      desc: '',
      args: [criteria],
    );
  }

  /// `Choose an icon`
  String get chooseAnIcon {
    return Intl.message(
      'Choose an icon',
      name: 'chooseAnIcon',
      desc: '',
      args: [],
    );
  }

  /// `Generate single password`
  String get generateSinglePassword {
    return Intl.message(
      'Generate single password',
      name: 'generateSinglePassword',
      desc: '',
      args: [],
    );
  }

  /// `Action needed`
  String get vaultStatusActionNeeded {
    return Intl.message(
      'Action needed',
      name: 'vaultStatusActionNeeded',
      desc: '',
      args: [],
    );
  }

  /// `Uploading`
  String get vaultStatusUploading {
    return Intl.message(
      'Uploading',
      name: 'vaultStatusUploading',
      desc: '',
      args: [],
    );
  }

  /// `Saving`
  String get vaultStatusSaving {
    return Intl.message(
      'Saving',
      name: 'vaultStatusSaving',
      desc: '',
      args: [],
    );
  }

  /// `Refreshing`
  String get vaultStatusRefreshing {
    return Intl.message(
      'Refreshing',
      name: 'vaultStatusRefreshing',
      desc: '',
      args: [],
    );
  }

  /// `Error`
  String get vaultStatusError {
    return Intl.message(
      'Error',
      name: 'vaultStatusError',
      desc: '',
      args: [],
    );
  }

  /// `Save needed`
  String get vaultStatusSaveNeeded {
    return Intl.message(
      'Save needed',
      name: 'vaultStatusSaveNeeded',
      desc: '',
      args: [],
    );
  }

  /// `Loaded`
  String get vaultStatusLoaded {
    return Intl.message(
      'Loaded',
      name: 'vaultStatusLoaded',
      desc: '',
      args: [],
    );
  }

  /// `Unknown state`
  String get vaultStatusUnknownState {
    return Intl.message(
      'Unknown state',
      name: 'vaultStatusUnknownState',
      desc: '',
      args: [],
    );
  }

  /// `Your password has changed`
  String get vaultStatusDescPasswordChanged {
    return Intl.message(
      'Your password has changed',
      name: 'vaultStatusDescPasswordChanged',
      desc: '',
      args: [],
    );
  }

  /// `Merging your changes from your other devices`
  String get vaultStatusDescMerging {
    return Intl.message(
      'Merging your changes from your other devices',
      name: 'vaultStatusDescMerging',
      desc: '',
      args: [],
    );
  }

  /// `Uploading your changes`
  String get vaultStatusDescUploading {
    return Intl.message(
      'Uploading your changes',
      name: 'vaultStatusDescUploading',
      desc: '',
      args: [],
    );
  }

  /// `Saving your changes`
  String get vaultStatusDescSaving {
    return Intl.message(
      'Saving your changes',
      name: 'vaultStatusDescSaving',
      desc: '',
      args: [],
    );
  }

  /// `Checking for changes from your other devices`
  String get vaultStatusDescRefreshing {
    return Intl.message(
      'Checking for changes from your other devices',
      name: 'vaultStatusDescRefreshing',
      desc: '',
      args: [],
    );
  }

  /// `There are changes from other devices which will be merged with this device when you next save.`
  String get vaultStatusDescSaveNeeded {
    return Intl.message(
      'There are changes from other devices which will be merged with this device when you next save.',
      name: 'vaultStatusDescSaveNeeded',
      desc: '',
      args: [],
    );
  }

  /// `Your Vault is loaded and ready for use.`
  String get vaultStatusDescLoaded {
    return Intl.message(
      'Your Vault is loaded and ready for use.',
      name: 'vaultStatusDescLoaded',
      desc: '',
      args: [],
    );
  }

  /// `If this situation does not automatically resolve itself within a minute, please check the Console Log in the Help section, report the problem and restart the app.`
  String get vaultStatusDescUnknown {
    return Intl.message(
      'If this situation does not automatically resolve itself within a minute, please check the Console Log in the Help section, report the problem and restart the app.',
      name: 'vaultStatusDescUnknown',
      desc: '',
      args: [],
    );
  }

  /// `Unlock your Vault`
  String get unlockRequired {
    return Intl.message(
      'Unlock your Vault',
      name: 'unlockRequired',
      desc: '',
      args: [],
    );
  }

  /// `Try again`
  String get tryAgain {
    return Intl.message(
      'Try again',
      name: 'tryAgain',
      desc: '',
      args: [],
    );
  }

  /// `Not signed in`
  String get notSignedIn {
    return Intl.message(
      'Not signed in',
      name: 'notSignedIn',
      desc: '',
      args: [],
    );
  }

  /// `Please re-enter your password`
  String get reenterYourPassword {
    return Intl.message(
      'Please re-enter your password',
      name: 'reenterYourPassword',
      desc: '',
      args: [],
    );
  }

  /// `Reveal search options and other filters`
  String get filterTooltipClosed {
    return Intl.message(
      'Reveal search options and other filters',
      name: 'filterTooltipClosed',
      desc: '',
      args: [],
    );
  }

  /// `Show matching entries`
  String get filterTooltipOpen {
    return Intl.message(
      'Show matching entries',
      name: 'filterTooltipOpen',
      desc: '',
      args: [],
    );
  }

  /// `New profile`
  String get newProfile {
    return Intl.message(
      'New profile',
      name: 'newProfile',
      desc: '',
      args: [],
    );
  }

  /// `You need to agree to the `
  String get localOnlyAgree1 {
    return Intl.message(
      'You need to agree to the ',
      name: 'localOnlyAgree1',
      desc: '',
      args: [],
    );
  }

  /// `Terms of Service and Privacy Statement`
  String get localOnlyAgree2 {
    return Intl.message(
      'Terms of Service and Privacy Statement',
      name: 'localOnlyAgree2',
      desc: '',
      args: [],
    );
  }

  /// `. We'll remember this until you uninstall the app or clear the app data. You MUST avoid clearing stored App data or you will also delete the passwords, usernames and other data you store in the app!`
  String get localOnlyAgree3 {
    return Intl.message(
      '. We\'ll remember this until you uninstall the app or clear the app data. You MUST avoid clearing stored App data or you will also delete the passwords, usernames and other data you store in the app!',
      name: 'localOnlyAgree3',
      desc: '',
      args: [],
    );
  }

  /// `I understand and agree to the above`
  String get localOnlyAgree4 {
    return Intl.message(
      'I understand and agree to the above',
      name: 'localOnlyAgree4',
      desc: '',
      args: [],
    );
  }

  /// `Creating`
  String get creating {
    return Intl.message(
      'Creating',
      name: 'creating',
      desc: '',
      args: [],
    );
  }

  /// `By using this app for free without an associated Kee Vault account, you are bound by the same terms and privacy policy as a user with an Account.`
  String get freeUserTermsPopup1 {
    return Intl.message(
      'By using this app for free without an associated Kee Vault account, you are bound by the same terms and privacy policy as a user with an Account.',
      name: 'freeUserTermsPopup1',
      desc: '',
      args: [],
    );
  }

  /// `However, some terms will obviously not be relevant to you immediately. To save time, you could skip these sections of the Terms of Service: B - Account Terms, E - Payment, F - Free Trial and G - Cancellation and Termination, although you might wish to review them anyway if you think that you may sign up for an Account one day in the future.`
  String get freeUserTermsPopup2 {
    return Intl.message(
      'However, some terms will obviously not be relevant to you immediately. To save time, you could skip these sections of the Terms of Service: B - Account Terms, E - Payment, F - Free Trial and G - Cancellation and Termination, although you might wish to review them anyway if you think that you may sign up for an Account one day in the future.',
      name: 'freeUserTermsPopup2',
      desc: '',
      args: [],
    );
  }

  /// `You can view the documents here:`
  String get freeUserTermsPopup3 {
    return Intl.message(
      'You can view the documents here:',
      name: 'freeUserTermsPopup3',
      desc: '',
      args: [],
    );
  }

  /// `You will be given a further opportunity to review these documents if you later create a Kee Vault account.`
  String get freeUserTermsPopup4 {
    return Intl.message(
      'You will be given a further opportunity to review these documents if you later create a Kee Vault account.',
      name: 'freeUserTermsPopup4',
      desc: '',
      args: [],
    );
  }

  /// `Please choose a password`
  String get chooseAPassword {
    return Intl.message(
      'Please choose a password',
      name: 'chooseAPassword',
      desc: '',
      args: [],
    );
  }

  /// `Kee Vault supports one free user on your device. The passwords you store into your Vault will be held securely on only this device so you should ensure that you do not delete the App's Data and that you take regular backups.`
  String get localOnlyIntro {
    return Intl.message(
      'Kee Vault supports one free user on your device. The passwords you store into your Vault will be held securely on only this device so you should ensure that you do not delete the App\'s Data and that you take regular backups.',
      name: 'localOnlyIntro',
      desc: '',
      args: [],
    );
  }

  /// `You have no password entries yet. Create one using the + button below.`
  String get noEntriesCreateNewInstruction {
    return Intl.message(
      'You have no password entries yet. Create one using the + button below.',
      name: 'noEntriesCreateNewInstruction',
      desc: '',
      args: [],
    );
  }

  /// `Enter your other password. This may be the old password you used on this device.`
  String get importUnlockRequired {
    return Intl.message(
      'Enter your other password. This may be the old password you used on this device.',
      name: 'importUnlockRequired',
      desc: '',
      args: [],
    );
  }

  /// `Thanks for signing in to a Kee Vault account. You already had a locally stored Vault on this device.`
  String get importedFree1 {
    return Intl.message(
      'Thanks for signing in to a Kee Vault account. You already had a locally stored Vault on this device.',
      name: 'importedFree1',
      desc: '',
      args: [],
    );
  }

  /// `We have automatically imported your local passwords to a new Group in your Kee Vault account. You may wish to rename the group or manually remove/edit the entries to resolve any duplication. You can read more about this and find more detailed instructions in `
  String get importedFree2 {
    return Intl.message(
      'We have automatically imported your local passwords to a new Group in your Kee Vault account. You may wish to rename the group or manually remove/edit the entries to resolve any duplication. You can read more about this and find more detailed instructions in ',
      name: 'importedFree2',
      desc: '',
      args: [],
    );
  }

  /// `this community forum topic`
  String get thisCommunityForumTopic {
    return Intl.message(
      'this community forum topic',
      name: 'thisCommunityForumTopic',
      desc: '',
      args: [],
    );
  }

  /// `We have imported your passwords to a new Group in your Kee Vault. You may wish to rename the group or manually remove/edit the entries to resolve any duplication. You can read more about this and find more detailed instructions in `
  String get importedManual {
    return Intl.message(
      'We have imported your passwords to a new Group in your Kee Vault. You may wish to rename the group or manually remove/edit the entries to resolve any duplication. You can read more about this and find more detailed instructions in ',
      name: 'importedManual',
      desc: '',
      args: [],
    );
  }

  /// `Import completed`
  String get importComplete {
    return Intl.message(
      'Import completed',
      name: 'importComplete',
      desc: '',
      args: [],
    );
  }

  /// `Continue to your Vault`
  String get importedContinueToVault {
    return Intl.message(
      'Continue to your Vault',
      name: 'importedContinueToVault',
      desc: '',
      args: [],
    );
  }

  /// `Export`
  String get export {
    return Intl.message(
      'Export',
      name: 'export',
      desc: '',
      args: [],
    );
  }

  /// `Import / Export`
  String get importExport {
    return Intl.message(
      'Import / Export',
      name: 'importExport',
      desc: '',
      args: [],
    );
  }

  /// `.kdbx file (Kee Vault, KeePass, etc.)`
  String get importKdbx {
    return Intl.message(
      '.kdbx file (Kee Vault, KeePass, etc.)',
      name: 'importKdbx',
      desc: '',
      args: [],
    );
  }

  /// `We'll try using the same password you have used to open your current Kee Vault. If that doesn't work, you can type in the correct password in a moment.`
  String get willTrySamePasswordFirst {
    return Intl.message(
      'We\'ll try using the same password you have used to open your current Kee Vault. If that doesn\'t work, you can type in the correct password in a moment.',
      name: 'willTrySamePasswordFirst',
      desc: '',
      args: [],
    );
  }

  /// `Kee Vault uses a standard format to securely store your passwords. You are free to export your passwords in this format to create a backup of your data. You can also import additional passwords to your vault from this screen.`
  String get keeVaultFormatExplainer {
    return Intl.message(
      'Kee Vault uses a standard format to securely store your passwords. You are free to export your passwords in this format to create a backup of your data. You can also import additional passwords to your vault from this screen.',
      name: 'keeVaultFormatExplainer',
      desc: '',
      args: [],
    );
  }

  /// `Exports are encrypted and can be unlocked using the same password you use to open your Kee Vault.`
  String get exportUsesCurrentPassword {
    return Intl.message(
      'Exports are encrypted and can be unlocked using the same password you use to open your Kee Vault.',
      name: 'exportUsesCurrentPassword',
      desc: '',
      args: [],
    );
  }

  /// `Remember that Exports do not automatically update. The information stored within and the password required to unlock it does not change after you create the export.`
  String get rememberExportsDoNotUpdate {
    return Intl.message(
      'Remember that Exports do not automatically update. The information stored within and the password required to unlock it does not change after you create the export.',
      name: 'rememberExportsDoNotUpdate',
      desc: '',
      args: [],
    );
  }

  /// `Remember chosen filter group`
  String get rememberFilterGroup {
    return Intl.message(
      'Remember chosen filter group',
      name: 'rememberFilterGroup',
      desc: '',
      args: [],
    );
  }

  /// `Show`
  String get show {
    return Intl.message(
      'Show',
      name: 'show',
      desc: '',
      args: [],
    );
  }

  /// `Hide`
  String get hide {
    return Intl.message(
      'Hide',
      name: 'hide',
      desc: '',
      args: [],
    );
  }

  /// `Reset entry to this state`
  String get resetEntryToThis {
    return Intl.message(
      'Reset entry to this state',
      name: 'resetEntryToThis',
      desc: '',
      args: [],
    );
  }

  /// `Entry history`
  String get entryHistory {
    return Intl.message(
      'Entry history',
      name: 'entryHistory',
      desc: '',
      args: [],
    );
  }

  /// `Old versions of this entry are listed below. If you need to revert to an older version, we will automatically add your latest saved version to this list.`
  String get entryHistoryExplainer {
    return Intl.message(
      'Old versions of this entry are listed below. If you need to revert to an older version, we will automatically add your latest saved version to this list.',
      name: 'entryHistoryExplainer',
      desc: '',
      args: [],
    );
  }

  /// `Your unsaved changes will be permanently lost if you change to this older version now. Do you want to discard your changes?`
  String get revertUnsavedWarning {
    return Intl.message(
      'Your unsaved changes will be permanently lost if you change to this older version now. Do you want to discard your changes?',
      name: 'revertUnsavedWarning',
      desc: '',
      args: [],
    );
  }

  /// `Medium-sized file attachments like this one are allowed. However, including more than a small number of them in your Vault will significantly slow down common tasks such as signing-in to your Vault and saving changes. Try to keep your attachments below 20KB`
  String get entryAttachmentSizeWarning {
    return Intl.message(
      'Medium-sized file attachments like this one are allowed. However, including more than a small number of them in your Vault will significantly slow down common tasks such as signing-in to your Vault and saving changes. Try to keep your attachments below 20KB',
      name: 'entryAttachmentSizeWarning',
      desc: '',
      args: [],
    );
  }

  /// `Large-sized file attachments like this one are not allowed because including them in your Vault will significantly slow down common tasks such as signing-in to your Vault and saving changes. Keep your attachments to a maximum of 250KB`
  String get entryAttachmentSizeError {
    return Intl.message(
      'Large-sized file attachments like this one are not allowed because including them in your Vault will significantly slow down common tasks such as signing-in to your Vault and saving changes. Keep your attachments to a maximum of 250KB',
      name: 'entryAttachmentSizeError',
      desc: '',
      args: [],
    );
  }

  /// `Add small attachment`
  String get addAttachment {
    return Intl.message(
      'Add small attachment',
      name: 'addAttachment',
      desc: '',
      args: [],
    );
  }

  /// `{count} bytes`
  String sizeBytes(Object count) {
    return Intl.message(
      '$count bytes',
      name: 'sizeBytes',
      desc: '',
      args: [count],
    );
  }

  /// `Delete attachment`
  String get deleteAttachment {
    return Intl.message(
      'Delete attachment',
      name: 'deleteAttachment',
      desc: '',
      args: [],
    );
  }

  /// `Share`
  String get share {
    return Intl.message(
      'Share',
      name: 'share',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete {name}`
  String attachmentConfirmDelete(Object name) {
    return Intl.message(
      'Are you sure you want to delete $name',
      name: 'attachmentConfirmDelete',
      desc: '',
      args: [name],
    );
  }

  /// `Delete`
  String get delete {
    return Intl.message(
      'Delete',
      name: 'delete',
      desc: '',
      args: [],
    );
  }

  /// `Permission error`
  String get permissionError {
    return Intl.message(
      'Permission error',
      name: 'permissionError',
      desc: '',
      args: [],
    );
  }

  /// `Sorry, we can't {action} unless you grant us permission. Please grant the permission in your settings and then try again.`
  String permissionDeniedPermanentlyError(Object action) {
    return Intl.message(
      'Sorry, we can\'t $action unless you grant us permission. Please grant the permission in your settings and then try again.',
      name: 'permissionDeniedPermanentlyError',
      desc: '',
      args: [action],
    );
  }

  /// `Cancel {action}`
  String cancelExportOrImport(Object action) {
    return Intl.message(
      'Cancel $action',
      name: 'cancelExportOrImport',
      desc: '',
      args: [action],
    );
  }

  /// `Open settings`
  String get openSettings {
    return Intl.message(
      'Open settings',
      name: 'openSettings',
      desc: '',
      args: [],
    );
  }

  /// `Sorry, we can't {action} unless you grant us permission. Please try again.`
  String permissionDeniedError(Object action) {
    return Intl.message(
      'Sorry, we can\'t $action unless you grant us permission. Please try again.',
      name: 'permissionDeniedError',
      desc: '',
      args: [action],
    );
  }

  /// `Export error`
  String get exportError {
    return Intl.message(
      'Export error',
      name: 'exportError',
      desc: '',
      args: [],
    );
  }

  /// `Import error`
  String get importError {
    return Intl.message(
      'Import error',
      name: 'importError',
      desc: '',
      args: [],
    );
  }

  /// `Sorry, we were unable to export to this location. Please check that you have enabled the necessary permissions for Kee Vault to access the file. If you still have problems please report it on the community forum along with full details of your device so that we can investigate whether we can add support for your particular device in future.`
  String get exportErrorDetails {
    return Intl.message(
      'Sorry, we were unable to export to this location. Please check that you have enabled the necessary permissions for Kee Vault to access the file. If you still have problems please report it on the community forum along with full details of your device so that we can investigate whether we can add support for your particular device in future.',
      name: 'exportErrorDetails',
      desc: '',
      args: [],
    );
  }

  /// `Sorry, we were unable to import this file. Please check that it is a valid KDBX file and that you have enabled the necessary permissions for Kee Vault to access the file. If you still have problems please report it on the community forum along with full details of your device so that we can investigate whether we can add support for your particular device in future.`
  String get importErrorDetails {
    return Intl.message(
      'Sorry, we were unable to import this file. Please check that it is a valid KDBX file and that you have enabled the necessary permissions for Kee Vault to access the file. If you still have problems please report it on the community forum along with full details of your device so that we can investigate whether we can add support for your particular device in future.',
      name: 'importErrorDetails',
      desc: '',
      args: [],
    );
  }

  /// `Sorry, we were unable to import this KDBX file. You probably need to save it in a different way. More details: `
  String get importErrorKdbx {
    return Intl.message(
      'Sorry, we were unable to import this KDBX file. You probably need to save it in a different way. More details: ',
      name: 'importErrorKdbx',
      desc: '',
      args: [],
    );
  }

  /// `We export the latest saved version of your Kee Vault. You may want to save your current changes before exporting.`
  String get exportDirtyFileWarning {
    return Intl.message(
      'We export the latest saved version of your Kee Vault. You may want to save your current changes before exporting.',
      name: 'exportDirtyFileWarning',
      desc: '',
      args: [],
    );
  }

  /// `Export anyway`
  String get exportAnyway {
    return Intl.message(
      'Export anyway',
      name: 'exportAnyway',
      desc: '',
      args: [],
    );
  }

  /// `Incorrect file`
  String get incorrectFile {
    return Intl.message(
      'Incorrect file',
      name: 'incorrectFile',
      desc: '',
      args: [],
    );
  }

  /// `Please select a KDBX file.`
  String get selectKdbxFile {
    return Intl.message(
      'Please select a KDBX file.',
      name: 'selectKdbxFile',
      desc: '',
      args: [],
    );
  }

  /// `Invalid TOTP code`
  String get otpManualError {
    return Intl.message(
      'Invalid TOTP code',
      name: 'otpManualError',
      desc: '',
      args: [],
    );
  }

  /// `You did not enter a valid TOTP base32 code. Please try again.`
  String get otpManualErrorBody {
    return Intl.message(
      'You did not enter a valid TOTP base32 code. Please try again.',
      name: 'otpManualErrorBody',
      desc: '',
      args: [],
    );
  }

  /// `Time-based One Time Password`
  String get otpManualTitle {
    return Intl.message(
      'Time-based One Time Password',
      name: 'otpManualTitle',
      desc: '',
      args: [],
    );
  }

  /// `TOTP code (base32 format)`
  String get otpCodeLabel {
    return Intl.message(
      'TOTP code (base32 format)',
      name: 'otpCodeLabel',
      desc: '',
      args: [],
    );
  }

  /// `Sorry, your device did not allow us to open the settings for this app. Please use your device settings app to find and change the permissions settings for Kee Vault and then return here to try again.`
  String get permissionSettingsOpenError {
    return Intl.message(
      'Sorry, your device did not allow us to open the settings for this app. Please use your device settings app to find and change the permissions settings for Kee Vault and then return here to try again.',
      name: 'permissionSettingsOpenError',
      desc: '',
      args: [],
    );
  }

  /// `Add field`
  String get addField {
    return Intl.message(
      'Add field',
      name: 'addField',
      desc: '',
      args: [],
    );
  }

  /// `Add TOTP / 2FA secret`
  String get addTOTPSecret {
    return Intl.message(
      'Add TOTP / 2FA secret',
      name: 'addTOTPSecret',
      desc: '',
      args: [],
    );
  }

  /// `Exported`
  String get exported {
    return Intl.message(
      'Exported',
      name: 'exported',
      desc: '',
      args: [],
    );
  }

  /// `Visit the forum`
  String get visitTheForum {
    return Intl.message(
      'Visit the forum',
      name: 'visitTheForum',
      desc: '',
      args: [],
    );
  }

  /// `Enter a number between {x} and {y}`
  String enterNumberBetweenXAndY(Object x, Object y) {
    return Intl.message(
      'Enter a number between $x and $y',
      name: 'enterNumberBetweenXAndY',
      desc: '',
      args: [x, y],
    );
  }

  /// `Require full password every (days)`
  String get requireFullPasswordEvery {
    return Intl.message(
      'Require full password every (days)',
      name: 'requireFullPasswordEvery',
      desc: '',
      args: [],
    );
  }

  /// `Automatically sign-in for (seconds)`
  String get automaticallySignInFor {
    return Intl.message(
      'Automatically sign-in for (seconds)',
      name: 'automaticallySignInFor',
      desc: '',
      args: [],
    );
  }

  /// `To access your passwords please confirm it's you`
  String get confirmItsYou {
    return Intl.message(
      'To access your passwords please confirm it\'s you',
      name: 'confirmItsYou',
      desc: '',
      args: [],
    );
  }

  /// `Remember your Vault password?`
  String get rememberVaultPassword {
    return Intl.message(
      'Remember your Vault password?',
      name: 'rememberVaultPassword',
      desc: '',
      args: [],
    );
  }

  /// `Access your passwords faster by protecting your password with biometrics`
  String get biometricsStoreDescription {
    return Intl.message(
      'Access your passwords faster by protecting your password with biometrics',
      name: 'biometricsStoreDescription',
      desc: '',
      args: [],
    );
  }

  /// `Hexadecimal`
  String get hexadecimal {
    return Intl.message(
      'Hexadecimal',
      name: 'hexadecimal',
      desc: '',
      args: [],
    );
  }

  /// `Open log console`
  String get openLogConsole {
    return Intl.message(
      'Open log console',
      name: 'openLogConsole',
      desc: '',
      args: [],
    );
  }

  /// `Autofilling`
  String get autofilling {
    return Intl.message(
      'Autofilling',
      name: 'autofilling',
      desc: '',
      args: [],
    );
  }

  /// `attach a file`
  String get permissionReasonAttachFile {
    return Intl.message(
      'attach a file',
      name: 'permissionReasonAttachFile',
      desc: '',
      args: [],
    );
  }

  /// `quickly scan QR codes (barcodes)`
  String get permissionReasonScanBarcodes {
    return Intl.message(
      'quickly scan QR codes (barcodes)',
      name: 'permissionReasonScanBarcodes',
      desc: '',
      args: [],
    );
  }

  /// `Attachment error`
  String get attachmentError {
    return Intl.message(
      'Attachment error',
      name: 'attachmentError',
      desc: '',
      args: [],
    );
  }

  /// `Sorry, we were unable to attach this file. Please check that you have enabled the necessary permissions for Kee Vault to access the file. If you still have problems please report it on the community forum along with full details of your device so that we can investigate whether we can add support for your particular device in future.`
  String get attachmentErrorDetails {
    return Intl.message(
      'Sorry, we were unable to attach this file. Please check that you have enabled the necessary permissions for Kee Vault to access the file. If you still have problems please report it on the community forum along with full details of your device so that we can investigate whether we can add support for your particular device in future.',
      name: 'attachmentErrorDetails',
      desc: '',
      args: [],
    );
  }

  /// ` : A field in this entry is corrupt. Please check the 'Help > Console log' for details.`
  String get errorCorruptField {
    return Intl.message(
      ' : A field in this entry is corrupt. Please check the \'Help > Console log\' for details.',
      name: 'errorCorruptField',
      desc: '',
      args: [],
    );
  }

  /// `Got it`
  String get gotIt {
    return Intl.message(
      'Got it',
      name: 'gotIt',
      desc: '',
      args: [],
    );
  }

  /// `Your password entries`
  String get yourPasswordEntries {
    return Intl.message(
      'Your password entries',
      name: 'yourPasswordEntries',
      desc: '',
      args: [],
    );
  }

  /// `\nSort your entries`
  String get introSortYourEntries {
    return Intl.message(
      '\nSort your entries',
      name: 'introSortYourEntries',
      desc: '',
      args: [],
    );
  }

  /// `\nFilter by group, label, colour and text`
  String get introFilter {
    return Intl.message(
      '\nFilter by group, label, colour and text',
      name: 'introFilter',
      desc: '',
      args: [],
    );
  }

  /// `Create secure password`
  String get createSecurePassword {
    return Intl.message(
      'Create secure password',
      name: 'createSecurePassword',
      desc: '',
      args: [],
    );
  }

  /// `Renaming field`
  String get renamingField {
    return Intl.message(
      'Renaming field',
      name: 'renamingField',
      desc: '',
      args: [],
    );
  }

  /// `Enter the new name for the field`
  String get renameFieldEnterNewName {
    return Intl.message(
      'Enter the new name for the field',
      name: 'renameFieldEnterNewName',
      desc: '',
      args: [],
    );
  }

  /// `Copy Secret`
  String get copySecret {
    return Intl.message(
      'Copy Secret',
      name: 'copySecret',
      desc: '',
      args: [],
    );
  }

  /// `New URL (include https://)`
  String get entryIntegrationHintNewUrl {
    return Intl.message(
      'New URL (include https://)',
      name: 'entryIntegrationHintNewUrl',
      desc: '',
      args: [],
    );
  }

  /// `New ID (e.g. com.example... )`
  String get entryIntegrationHintNewId {
    return Intl.message(
      'New ID (e.g. com.example... )',
      name: 'entryIntegrationHintNewId',
      desc: '',
      args: [],
    );
  }

  /// `Protected field. Click to reveal.`
  String get protectedClickToReveal {
    return Intl.message(
      'Protected field. Click to reveal.',
      name: 'protectedClickToReveal',
      desc: '',
      args: [],
    );
  }

  /// `Show protected field`
  String get showProtectedField {
    return Intl.message(
      'Show protected field',
      name: 'showProtectedField',
      desc: '',
      args: [],
    );
  }

  /// `Renaming preset`
  String get renamingPreset {
    return Intl.message(
      'Renaming preset',
      name: 'renamingPreset',
      desc: '',
      args: [],
    );
  }

  /// `Enter the new name for the preset`
  String get enterNewPresetName {
    return Intl.message(
      'Enter the new name for the preset',
      name: 'enterNewPresetName',
      desc: '',
      args: [],
    );
  }

  /// `Search`
  String get search {
    return Intl.message(
      'Search',
      name: 'search',
      desc: '',
      args: [],
    );
  }

  /// `name`
  String get name {
    return Intl.message(
      'name',
      name: 'name',
      desc: '',
      args: [],
    );
  }

  /// `title`
  String get title {
    return Intl.message(
      'title',
      name: 'title',
      desc: '',
      args: [],
    );
  }

  /// `user`
  String get user {
    return Intl.message(
      'user',
      name: 'user',
      desc: '',
      args: [],
    );
  }

  /// `User/Email`
  String get userEmail {
    return Intl.message(
      'User/Email',
      name: 'userEmail',
      desc: '',
      args: [],
    );
  }

  /// `group`
  String get group {
    return Intl.message(
      'group',
      name: 'group',
      desc: '',
      args: [],
    );
  }

  /// `Save changes`
  String get saveChanges {
    return Intl.message(
      'Save changes',
      name: 'saveChanges',
      desc: '',
      args: [],
    );
  }

  /// `Discard changes`
  String get discardChanges {
    return Intl.message(
      'Discard changes',
      name: 'discardChanges',
      desc: '',
      args: [],
    );
  }

  /// `Help`
  String get help {
    return Intl.message(
      'Help',
      name: 'help',
      desc: '',
      args: [],
    );
  }

  /// `Settings`
  String get settings {
    return Intl.message(
      'Settings',
      name: 'settings',
      desc: '',
      args: [],
    );
  }

  /// `Bin`
  String get menuTrash {
    return Intl.message(
      'Bin',
      name: 'menuTrash',
      desc: '',
      args: [],
    );
  }

  /// `General`
  String get menuSetGeneral {
    return Intl.message(
      'General',
      name: 'menuSetGeneral',
      desc: '',
      args: [],
    );
  }

  /// `Empty Bin`
  String get menuEmptyTrash {
    return Intl.message(
      'Empty Bin',
      name: 'menuEmptyTrash',
      desc: '',
      args: [],
    );
  }

  /// `Empty Bin?`
  String get menuEmptyTrashAlert {
    return Intl.message(
      'Empty Bin?',
      name: 'menuEmptyTrashAlert',
      desc: '',
      args: [],
    );
  }

  /// `You will not be able to get the entries back`
  String get menuEmptyTrashAlertBody {
    return Intl.message(
      'You will not be able to get the entries back',
      name: 'menuEmptyTrashAlertBody',
      desc: '',
      args: [],
    );
  }

  /// `Yes`
  String get alertYes {
    return Intl.message(
      'Yes',
      name: 'alertYes',
      desc: '',
      args: [],
    );
  }

  /// `No`
  String get alertNo {
    return Intl.message(
      'No',
      name: 'alertNo',
      desc: '',
      args: [],
    );
  }

  /// `OK`
  String get alertOk {
    return Intl.message(
      'OK',
      name: 'alertOk',
      desc: '',
      args: [],
    );
  }

  /// `Cancel`
  String get alertCancel {
    return Intl.message(
      'Cancel',
      name: 'alertCancel',
      desc: '',
      args: [],
    );
  }

  /// `Copy`
  String get alertCopy {
    return Intl.message(
      'Copy',
      name: 'alertCopy',
      desc: '',
      args: [],
    );
  }

  /// `Close`
  String get alertClose {
    return Intl.message(
      'Close',
      name: 'alertClose',
      desc: '',
      args: [],
    );
  }

  /// `Generate`
  String get footerTitleGen {
    return Intl.message(
      'Generate',
      name: 'footerTitleGen',
      desc: '',
      args: [],
    );
  }

  /// `Length`
  String get genLen {
    return Intl.message(
      'Length',
      name: 'genLen',
      desc: '',
      args: [],
    );
  }

  /// `Pronounceable`
  String get genPresetPronounceable {
    return Intl.message(
      'Pronounceable',
      name: 'genPresetPronounceable',
      desc: '',
      args: [],
    );
  }

  /// `Medium security`
  String get genPresetMed {
    return Intl.message(
      'Medium security',
      name: 'genPresetMed',
      desc: '',
      args: [],
    );
  }

  /// `High security`
  String get genPresetHigh {
    return Intl.message(
      'High security',
      name: 'genPresetHigh',
      desc: '',
      args: [],
    );
  }

  /// `Very high security`
  String get genPresetVeryHigh {
    return Intl.message(
      'Very high security',
      name: 'genPresetVeryHigh',
      desc: '',
      args: [],
    );
  }

  /// `4-digit PIN`
  String get genPresetPin4 {
    return Intl.message(
      '4-digit PIN',
      name: 'genPresetPin4',
      desc: '',
      args: [],
    );
  }

  /// `MAC address`
  String get genPresetMac {
    return Intl.message(
      'MAC address',
      name: 'genPresetMac',
      desc: '',
      args: [],
    );
  }

  /// `Rename`
  String get tagRename {
    return Intl.message(
      'Rename',
      name: 'tagRename',
      desc: '',
      args: [],
    );
  }

  /// `Generator Presets`
  String get genPsTitle {
    return Intl.message(
      'Generator Presets',
      name: 'genPsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Delete preset`
  String get genPsDelete {
    return Intl.message(
      'Delete preset',
      name: 'genPsDelete',
      desc: '',
      args: [],
    );
  }

  /// `Selected by default`
  String get genPsDefault {
    return Intl.message(
      'Selected by default',
      name: 'genPsDefault',
      desc: '',
      args: [],
    );
  }

  /// `Uppercase latin letters`
  String get genPsUpper {
    return Intl.message(
      'Uppercase latin letters',
      name: 'genPsUpper',
      desc: '',
      args: [],
    );
  }

  /// `Lowercase latin letters`
  String get genPsLower {
    return Intl.message(
      'Lowercase latin letters',
      name: 'genPsLower',
      desc: '',
      args: [],
    );
  }

  /// `Digits`
  String get genPsDigits {
    return Intl.message(
      'Digits',
      name: 'genPsDigits',
      desc: '',
      args: [],
    );
  }

  /// `Special symbols`
  String get genPsSpecial {
    return Intl.message(
      'Special symbols',
      name: 'genPsSpecial',
      desc: '',
      args: [],
    );
  }

  /// `Brackets`
  String get genPsBrackets {
    return Intl.message(
      'Brackets',
      name: 'genPsBrackets',
      desc: '',
      args: [],
    );
  }

  /// `High ASCII characters`
  String get genPsHigh {
    return Intl.message(
      'High ASCII characters',
      name: 'genPsHigh',
      desc: '',
      args: [],
    );
  }

  /// `Ambiguous symbols`
  String get genPsAmbiguous {
    return Intl.message(
      'Ambiguous symbols',
      name: 'genPsAmbiguous',
      desc: '',
      args: [],
    );
  }

  /// `Match case`
  String get searchCase {
    return Intl.message(
      'Match case',
      name: 'searchCase',
      desc: '',
      args: [],
    );
  }

  /// `RegEx`
  String get searchRegex {
    return Intl.message(
      'RegEx',
      name: 'searchRegex',
      desc: '',
      args: [],
    );
  }

  /// `URL`
  String get openUrl {
    return Intl.message(
      'URL',
      name: 'openUrl',
      desc: '',
      args: [],
    );
  }

  /// `Error`
  String get openError {
    return Intl.message(
      'Error',
      name: 'openError',
      desc: '',
      args: [],
    );
  }

  /// `Revert to state`
  String get detHistoryRevert {
    return Intl.message(
      'Revert to state',
      name: 'detHistoryRevert',
      desc: '',
      args: [],
    );
  }

  /// `Revert to this history state?`
  String get detHistoryRevertAlert {
    return Intl.message(
      'Revert to this history state?',
      name: 'detHistoryRevertAlert',
      desc: '',
      args: [],
    );
  }

  /// `Change icon`
  String get detSetIcon {
    return Intl.message(
      'Change icon',
      name: 'detSetIcon',
      desc: '',
      args: [],
    );
  }

  /// `Delete`
  String get detDelEntry {
    return Intl.message(
      'Delete',
      name: 'detDelEntry',
      desc: '',
      args: [],
    );
  }

  /// `Delete permanently`
  String get detDelEntryPerm {
    return Intl.message(
      'Delete permanently',
      name: 'detDelEntryPerm',
      desc: '',
      args: [],
    );
  }

  /// `Group`
  String get detGroup {
    return Intl.message(
      'Group',
      name: 'detGroup',
      desc: '',
      args: [],
    );
  }

  /// `Created`
  String get detCreated {
    return Intl.message(
      'Created',
      name: 'detCreated',
      desc: '',
      args: [],
    );
  }

  /// `Updated`
  String get detUpdated {
    return Intl.message(
      'Updated',
      name: 'detUpdated',
      desc: '',
      args: [],
    );
  }

  /// `New Field`
  String get detNetField {
    return Intl.message(
      'New Field',
      name: 'detNetField',
      desc: '',
      args: [],
    );
  }

  /// `Copied`
  String get detFieldCopied {
    return Intl.message(
      'Copied',
      name: 'detFieldCopied',
      desc: '',
      args: [],
    );
  }

  /// `"One Time Passwords" (OTP) are a feature some websites offer to improve security. It is a type of Two/Multi Factor Authentication (2FA/MFA).`
  String get otpExplainer1 {
    return Intl.message(
      '"One Time Passwords" (OTP) are a feature some websites offer to improve security. It is a type of Two/Multi Factor Authentication (2FA/MFA).',
      name: 'otpExplainer1',
      desc: '',
      args: [],
    );
  }

  /// `Enter code manually`
  String get detSetupOtpManualButton {
    return Intl.message(
      'Enter code manually',
      name: 'detSetupOtpManualButton',
      desc: '',
      args: [],
    );
  }

  /// `QR code scan error`
  String get detOtpQrError {
    return Intl.message(
      'QR code scan error',
      name: 'detOtpQrError',
      desc: '',
      args: [],
    );
  }

  /// `Sorry, we could not read the QR code, please try once again or contact the app authors with error details.`
  String get detOtpQrErrorBody {
    return Intl.message(
      'Sorry, we could not read the QR code, please try once again or contact the app authors with error details.',
      name: 'detOtpQrErrorBody',
      desc: '',
      args: [],
    );
  }

  /// `Wrong QR code`
  String get detOtpQrWrong {
    return Intl.message(
      'Wrong QR code',
      name: 'detOtpQrWrong',
      desc: '',
      args: [],
    );
  }

  /// `Your QR code was successfully scanned but it doesn't contain one-time password data.`
  String get detOtpQrWrongBody {
    return Intl.message(
      'Your QR code was successfully scanned but it doesn\'t contain one-time password data.',
      name: 'detOtpQrWrongBody',
      desc: '',
      args: [],
    );
  }

  /// `You have unsaved changes that will be lost. Continue?`
  String get appCannotLock {
    return Intl.message(
      'You have unsaved changes that will be lost. Continue?',
      name: 'appCannotLock',
      desc: '',
      args: [],
    );
  }

  /// `Theme`
  String get setGenTheme {
    return Intl.message(
      'Theme',
      name: 'setGenTheme',
      desc: '',
      args: [],
    );
  }

  /// `Light`
  String get setGenThemeLt {
    return Intl.message(
      'Light',
      name: 'setGenThemeLt',
      desc: '',
      args: [],
    );
  }

  /// `Dark`
  String get setGenThemeDk {
    return Intl.message(
      'Dark',
      name: 'setGenThemeDk',
      desc: '',
      args: [],
    );
  }

  /// `Default`
  String get setGenTitlebarStyleDefault {
    return Intl.message(
      'Default',
      name: 'setGenTitlebarStyleDefault',
      desc: '',
      args: [],
    );
  }

  /// `Show entries from all subgroups`
  String get setGenShowSubgroups {
    return Intl.message(
      'Show entries from all subgroups',
      name: 'setGenShowSubgroups',
      desc: '',
      args: [],
    );
  }

  /// `passwords don't match, please type it again`
  String get setFilePassNotMatch {
    return Intl.message(
      'passwords don\'t match, please type it again',
      name: 'setFilePassNotMatch',
      desc: '',
      args: [],
    );
  }

  /// `Sign in`
  String get signin {
    return Intl.message(
      'Sign in',
      name: 'signin',
      desc: '',
      args: [],
    );
  }

  /// `Sign out`
  String get signout {
    return Intl.message(
      'Sign out',
      name: 'signout',
      desc: '',
      args: [],
    );
  }

  /// `Create my Vault`
  String get createVault {
    return Intl.message(
      'Create my Vault',
      name: 'createVault',
      desc: '',
      args: [],
    );
  }

  /// `Choose a very secure password to protect your Kee Vault. Only you will know this password - it never leaves your device. It can not be reset. You must remember it. You can change it in future.`
  String get registrationBlurb1 {
    return Intl.message(
      'Choose a very secure password to protect your Kee Vault. Only you will know this password - it never leaves your device. It can not be reset. You must remember it. You can change it in future.',
      name: 'registrationBlurb1',
      desc: '',
      args: [],
    );
  }

  /// `New password`
  String get newPassword {
    return Intl.message(
      'New password',
      name: 'newPassword',
      desc: '',
      args: [],
    );
  }

  /// `New password (please repeat)`
  String get newPasswordRepeat {
    return Intl.message(
      'New password (please repeat)',
      name: 'newPasswordRepeat',
      desc: '',
      args: [],
    );
  }

  /// `Sign in failed because the response we received from the server indicates that it may be compromised. The most likely explanation is that someone near you or at your internet service provider is attempting to interfere with the secure connection and connect you to a malicious server (A Miscreant In The Middle attack). Find a different internet connection immediately, shut down the Kee Vault app and try again. If it keeps happening, your local device may be compromised. The security of your Kee Vault remains intact so you need not panic. More information about the error is available at https://forum.kee.pm/`
  String get serverMITMWarning {
    return Intl.message(
      'Sign in failed because the response we received from the server indicates that it may be compromised. The most likely explanation is that someone near you or at your internet service provider is attempting to interfere with the secure connection and connect you to a malicious server (A Miscreant In The Middle attack). Find a different internet connection immediately, shut down the Kee Vault app and try again. If it keeps happening, your local device may be compromised. The security of your Kee Vault remains intact so you need not panic. More information about the error is available at https://forum.kee.pm/',
      name: 'serverMITMWarning',
      desc: '',
      args: [],
    );
  }

  /// `Import`
  String get import {
    return Intl.message(
      'Import',
      name: 'import',
      desc: '',
      args: [],
    );
  }

  /// `We'll add specialised support for some other password manager storage formats in future but won't ever be able to directly support every one of the hundreds available.`
  String get importOtherInstructions1 {
    return Intl.message(
      'We\'ll add specialised support for some other password manager storage formats in future but won\'t ever be able to directly support every one of the hundreds available.',
      name: 'importOtherInstructions1',
      desc: '',
      args: [],
    );
  }

  /// `If you don't already have a file in the KDBX format, you could use the desktop computer version of KeePass Password Safe 2 to import from your original source, save the KDBX file and then import that here using the kdbx import option.`
  String get importOtherInstructions4 {
    return Intl.message(
      'If you don\'t already have a file in the KDBX format, you could use the desktop computer version of KeePass Password Safe 2 to import from your original source, save the KDBX file and then import that here using the kdbx import option.',
      name: 'importOtherInstructions4',
      desc: '',
      args: [],
    );
  }

  /// `Domain`
  String get domain {
    return Intl.message(
      'Domain',
      name: 'domain',
      desc: '',
      args: [],
    );
  }

  /// `Exact`
  String get exact {
    return Intl.message(
      'Exact',
      name: 'exact',
      desc: '',
      args: [],
    );
  }

  /// `Hostname`
  String get hostname {
    return Intl.message(
      'Hostname',
      name: 'hostname',
      desc: '',
      args: [],
    );
  }

  /// `Minimum accuracy for a URL match`
  String get minURLMatchAccuracy {
    return Intl.message(
      'Minimum accuracy for a URL match',
      name: 'minURLMatchAccuracy',
      desc: '',
      args: [],
    );
  }

  /// `Text`
  String get text {
    return Intl.message(
      'Text',
      name: 'text',
      desc: '',
      args: [],
    );
  }

  /// `Field name`
  String get fieldName {
    return Intl.message(
      'Field name',
      name: 'fieldName',
      desc: '',
      args: [],
    );
  }

  /// `Enabled`
  String get enabled {
    return Intl.message(
      'Enabled',
      name: 'enabled',
      desc: '',
      args: [],
    );
  }

  /// `Disabled`
  String get disabled {
    return Intl.message(
      'Disabled',
      name: 'disabled',
      desc: '',
      args: [],
    );
  }

  /// `Protect field`
  String get protectField {
    return Intl.message(
      'Protect field',
      name: 'protectField',
      desc: '',
      args: [],
    );
  }

  /// `Unprotect field`
  String get unprotectField {
    return Intl.message(
      'Unprotect field',
      name: 'unprotectField',
      desc: '',
      args: [],
    );
  }

  /// `Apply`
  String get apply {
    return Intl.message(
      'Apply',
      name: 'apply',
      desc: '',
      args: [],
    );
  }

  /// `Saving...`
  String get saveExplainerAlertTitle {
    return Intl.message(
      'Saving...',
      name: 'saveExplainerAlertTitle',
      desc: '',
      args: [],
    );
  }

  /// `Create new entry`
  String get createNewEntry {
    return Intl.message(
      'Create new entry',
      name: 'createNewEntry',
      desc: '',
      args: [],
    );
  }

  /// `Entry saved. Make changes below if you want and then click "Done" above.`
  String get autofillNewEntryMakeChangesThenDone {
    return Intl.message(
      'Entry saved. Make changes below if you want and then click "Done" above.',
      name: 'autofillNewEntryMakeChangesThenDone',
      desc: '',
      args: [],
    );
  }

  /// `Done`
  String get done {
    return Intl.message(
      'Done',
      name: 'done',
      desc: '',
      args: [],
    );
  }

  /// `Offer to save passwords`
  String get offerToSave {
    return Intl.message(
      'Offer to save passwords',
      name: 'offerToSave',
      desc: '',
      args: [],
    );
  }

  /// `Subscription expired`
  String get subscriptionExpired {
    return Intl.message(
      'Subscription expired',
      name: 'subscriptionExpired',
      desc: '',
      args: [],
    );
  }

  /// `Your subscription or trial period has ended. Provide up to date payment details and re-enable your subscription on the Kee Vault Account Management web site.`
  String get subscriptionExpiredDetails {
    return Intl.message(
      'Your subscription or trial period has ended. Provide up to date payment details and re-enable your subscription on the Kee Vault Account Management web site.',
      name: 'subscriptionExpiredDetails',
      desc: '',
      args: [],
    );
  }

  /// `Restart subscription`
  String get restartSubscription {
    return Intl.message(
      'Restart subscription',
      name: 'restartSubscription',
      desc: '',
      args: [],
    );
  }

  /// `Welcome back to Kee Vault. You can enable a new 30 day free trial to see what has improved since you first created your Kee Vault account.`
  String get subscriptionExpiredTrialAvailable {
    return Intl.message(
      'Welcome back to Kee Vault. You can enable a new 30 day free trial to see what has improved since you first created your Kee Vault account.',
      name: 'subscriptionExpiredTrialAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Start free trial`
  String get startFreeTrial {
    return Intl.message(
      'Start free trial',
      name: 'startFreeTrial',
      desc: '',
      args: [],
    );
  }

  /// `Sorry, we weren't able to restart your trial now. Please try again later and ask for help on the community forum if the problem continues.`
  String get startNewTrialError {
    return Intl.message(
      'Sorry, we weren\'t able to restart your trial now. Please try again later and ask for help on the community forum if the problem continues.',
      name: 'startNewTrialError',
      desc: '',
      args: [],
    );
  }

  /// `All done!`
  String get startNewTrialSuccess {
    return Intl.message(
      'All done!',
      name: 'startNewTrialSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Want to hear about new features?`
  String get bannerMsg1TitleA {
    return Intl.message(
      'Want to hear about new features?',
      name: 'bannerMsg1TitleA',
      desc: '',
      args: [],
    );
  }

  /// `Want to hear about new features and how to register for automatic backups and access from your other devices?`
  String get bannerMsg1TitleB {
    return Intl.message(
      'Want to hear about new features and how to register for automatic backups and access from your other devices?',
      name: 'bannerMsg1TitleB',
      desc: '',
      args: [],
    );
  }

  /// `The same privacy policy applies as when you started using the app. In brief, we'll protect (encrypt) your email address when we store it and will never share it or use it for anything you haven't agreed to. You can unsubscribe easily from each email we send to you.`
  String get prcRegistrationPrivacy1 {
    return Intl.message(
      'The same privacy policy applies as when you started using the app. In brief, we\'ll protect (encrypt) your email address when we store it and will never share it or use it for anything you haven\'t agreed to. You can unsubscribe easily from each email we send to you.',
      name: 'prcRegistrationPrivacy1',
      desc: '',
      args: [],
    );
  }

  /// `You can review the full policy here:`
  String get prcRegistrationPrivacy2 {
    return Intl.message(
      'You can review the full policy here:',
      name: 'prcRegistrationPrivacy2',
      desc: '',
      args: [],
    );
  }

  /// `Sign up to receive emails`
  String get prcRegistrationSignUpButton {
    return Intl.message(
      'Sign up to receive emails',
      name: 'prcRegistrationSignUpButton',
      desc: '',
      args: [],
    );
  }

  /// `Remind me...`
  String get prcRegistrationReminderDelayRemindMe {
    return Intl.message(
      'Remind me...',
      name: 'prcRegistrationReminderDelayRemindMe',
      desc: '',
      args: [],
    );
  }

  /// `in 3 days`
  String get prcRegistrationReminderDelay3days {
    return Intl.message(
      'in 3 days',
      name: 'prcRegistrationReminderDelay3days',
      desc: '',
      args: [],
    );
  }

  /// `in 3 weeks`
  String get prcRegistrationReminderDelay3weeks {
    return Intl.message(
      'in 3 weeks',
      name: 'prcRegistrationReminderDelay3weeks',
      desc: '',
      args: [],
    );
  }

  /// `in 3 months`
  String get prcRegistrationReminderDelay3months {
    return Intl.message(
      'in 3 months',
      name: 'prcRegistrationReminderDelay3months',
      desc: '',
      args: [],
    );
  }

  /// `never`
  String get prcRegistrationReminderDelayNever {
    return Intl.message(
      'never',
      name: 'prcRegistrationReminderDelayNever',
      desc: '',
      args: [],
    );
  }

  /// `Privacy Statement`
  String get privacyStatement {
    return Intl.message(
      'Privacy Statement',
      name: 'privacyStatement',
      desc: '',
      args: [],
    );
  }

  /// `Yes please`
  String get alertYesPlease {
    return Intl.message(
      'Yes please',
      name: 'alertYesPlease',
      desc: '',
      args: [],
    );
  }

  /// `Sorry, we weren't able to register your email address now. Please check that you have a good network connection and try again or ask for help on the community forum if the problem continues.`
  String get prcRegistrationError {
    return Intl.message(
      'Sorry, we weren\'t able to register your email address now. Please check that you have a good network connection and try again or ask for help on the community forum if the problem continues.',
      name: 'prcRegistrationError',
      desc: '',
      args: [],
    );
  }

  /// `Success! Please check your emails soon to confirm that you want to receive updates from us.`
  String get prcRegistrationSuccess {
    return Intl.message(
      'Success! Please check your emails soon to confirm that you want to receive updates from us.',
      name: 'prcRegistrationSuccess',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
