// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  static String m0(name) => "Are you sure you want to delete ${name}";

  static String m1(action) => "Cancel ${action}";

  static String m2(name) => "Select the new parent for the \"${name}\" group";

  static String m3(appName) =>
      "You must change your device\'s Autofill provider to ${appName}.";

  static String m4(x, y) => "Enter a number between ${x} and ${y}";

  static String m5(criteria) => "Filtered by ${criteria}";

  static String m6(action) =>
      "Sorry, we can\'t ${action} unless you grant us permission. Please try again.";

  static String m7(action) =>
      "Sorry, we can\'t ${action} unless you grant us permission. Please grant the permission in your settings and then try again.";

  static String m8(email) =>
      "You can click the button below to agree to receive occasional marketing emails from us and allow us to check the status of any Kee Vault account associated with ${email}";

  static String m9(count) => "${count} bytes";

  static String m10(error) =>
      "Unexpected error. Sorry! Please let us know, then close and restart the app. Details: ${error}";

  static String m11(email) => "Welcome ${email}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "add": MessageLookupByLibrary.simpleMessage("Add"),
        "addAttachment":
            MessageLookupByLibrary.simpleMessage("Add small attachment"),
        "addField": MessageLookupByLibrary.simpleMessage("Add field"),
        "addTOTPSecret":
            MessageLookupByLibrary.simpleMessage("Add TOTP / 2FA secret"),
        "additionalCharacters":
            MessageLookupByLibrary.simpleMessage("Additional characters"),
        "additionalUrlsToMatch":
            MessageLookupByLibrary.simpleMessage("Additional URLs to match"),
        "agreeAndCheckAccountStatus": MessageLookupByLibrary.simpleMessage(
            "Agree and check account status"),
        "alertCancel": MessageLookupByLibrary.simpleMessage("Cancel"),
        "alertClose": MessageLookupByLibrary.simpleMessage("Close"),
        "alertCopy": MessageLookupByLibrary.simpleMessage("Copy"),
        "alertNo": MessageLookupByLibrary.simpleMessage("No"),
        "alertOk": MessageLookupByLibrary.simpleMessage("OK"),
        "alertYes": MessageLookupByLibrary.simpleMessage("Yes"),
        "alertYesPlease": MessageLookupByLibrary.simpleMessage("Yes please"),
        "androidAppIdsToMatch": MessageLookupByLibrary.simpleMessage(
            "Android app technical names to match"),
        "appCannotLock": MessageLookupByLibrary.simpleMessage(
            "You have unsaved changes that will be lost. Continue?"),
        "apply": MessageLookupByLibrary.simpleMessage("Apply"),
        "attachmentConfirmDelete": m0,
        "attachmentError":
            MessageLookupByLibrary.simpleMessage("Attachment error"),
        "attachmentErrorDetails": MessageLookupByLibrary.simpleMessage(
            "Sorry, we were unable to attach this file. Please check that you have enabled the necessary permissions for Kee Vault to access the file. If you still have problems please report it on the community forum along with full details of your device so that we can investigate whether we can add support for your particular device in future."),
        "authenticating":
            MessageLookupByLibrary.simpleMessage("Authenticating"),
        "autofillEnabled": MessageLookupByLibrary.simpleMessage(
            "Kee Vault is correctly set as your device\'s Autofill provider."),
        "autofillNewEntryMakeChangesThenDone": MessageLookupByLibrary.simpleMessage(
            "Entry saved. Make changes below if you want and then click \"Done\" above."),
        "autofilling": MessageLookupByLibrary.simpleMessage("Autofilling"),
        "automaticallySignInFor": MessageLookupByLibrary.simpleMessage(
            "Automatically sign-in for (seconds)"),
        "bannerMsg1TitleA": MessageLookupByLibrary.simpleMessage(
            "Want to hear about new features?"),
        "bannerMsg1TitleB": MessageLookupByLibrary.simpleMessage(
            "Want to hear about new features and how to register for automatic backups and access from your other devices?"),
        "bannerMsgAutofillDisabled": MessageLookupByLibrary.simpleMessage(
            "For easier sign-in to your apps and websites, you need to change your device\'s Autofill provider to Kee Vault."),
        "bannerMsgSaving1": MessageLookupByLibrary.simpleMessage(
            "Your Vault is being saved when this lock icon is flashing at the bottom of the screen."),
        "bannerMsgSaving2": MessageLookupByLibrary.simpleMessage(
            "Our high security protection is applied to your Vault every time you save it. This can take a little bit of time, and a slow internet connection can make it take longer too."),
        "bannerReminderDelay3days":
            MessageLookupByLibrary.simpleMessage("in 3 days"),
        "bannerReminderDelay3months":
            MessageLookupByLibrary.simpleMessage("in 3 months"),
        "bannerReminderDelay3weeks":
            MessageLookupByLibrary.simpleMessage("in 3 weeks"),
        "bannerReminderDelayNever":
            MessageLookupByLibrary.simpleMessage("never"),
        "bannerReminderDelayRemindMe":
            MessageLookupByLibrary.simpleMessage("Remind me..."),
        "bigTechAntiCompetitionStatement": MessageLookupByLibrary.simpleMessage(
            "The \"Big Tech\" companies prohibit us from directly linking to the account registration page on our website."),
        "biometricSignIn":
            MessageLookupByLibrary.simpleMessage("Biometric sign-in"),
        "biometricsStoreDescription": MessageLookupByLibrary.simpleMessage(
            "Access your passwords faster by protecting your password with biometrics"),
        "cancelExportOrImport": m1,
        "changePassword":
            MessageLookupByLibrary.simpleMessage("Change Password"),
        "changePasswordDetail": MessageLookupByLibrary.simpleMessage(
            "Change the password you use to sign in to Kee Vault"),
        "chooseAPassword":
            MessageLookupByLibrary.simpleMessage("Please choose a password"),
        "chooseAnIcon": MessageLookupByLibrary.simpleMessage("Choose an icon"),
        "chooseNewParentGroupForEntry": MessageLookupByLibrary.simpleMessage(
            "Select the group for this entry"),
        "chooseNewParentGroupForGroup": m2,
        "chooseRestoreGroup": MessageLookupByLibrary.simpleMessage(
            "Select the group in which to restore this item"),
        "color": MessageLookupByLibrary.simpleMessage("Colour"),
        "colorFilteringHint": MessageLookupByLibrary.simpleMessage(
            "Select colours above to display only entries with a matching colour."),
        "colors": MessageLookupByLibrary.simpleMessage("Colours"),
        "colorsExplanation": MessageLookupByLibrary.simpleMessage(
            "Colours allow you to categorise your entries in a more simplistic and visual way than Groups or Labels."),
        "confirmItsYou": MessageLookupByLibrary.simpleMessage(
            "To access your passwords please confirm it\'s you"),
        "copySecret": MessageLookupByLibrary.simpleMessage("Copy Secret"),
        "createNewEntry":
            MessageLookupByLibrary.simpleMessage("Create new entry"),
        "createSecurePassword":
            MessageLookupByLibrary.simpleMessage("Create secure password"),
        "createVault": MessageLookupByLibrary.simpleMessage("Create my Vault"),
        "creating": MessageLookupByLibrary.simpleMessage("Creating"),
        "currentPassword":
            MessageLookupByLibrary.simpleMessage("Current Password"),
        "currentPasswordNotCorrect": MessageLookupByLibrary.simpleMessage(
            "Current password is not correct"),
        "delete": MessageLookupByLibrary.simpleMessage("Delete"),
        "deleteAttachment":
            MessageLookupByLibrary.simpleMessage("Delete attachment"),
        "deleteGroupConfirm": MessageLookupByLibrary.simpleMessage(
            "Delete the group and all entries within it?"),
        "detCreated": MessageLookupByLibrary.simpleMessage("Created"),
        "detDelEntry": MessageLookupByLibrary.simpleMessage("Delete"),
        "detDelEntryPerm":
            MessageLookupByLibrary.simpleMessage("Delete permanently"),
        "detFieldCopied": MessageLookupByLibrary.simpleMessage("Copied"),
        "detGroup": MessageLookupByLibrary.simpleMessage("Group"),
        "detHistoryRevert":
            MessageLookupByLibrary.simpleMessage("Revert to state"),
        "detHistoryRevertAlert": MessageLookupByLibrary.simpleMessage(
            "Revert to this history state?"),
        "detNetField": MessageLookupByLibrary.simpleMessage("New Field"),
        "detOtpQrError":
            MessageLookupByLibrary.simpleMessage("QR code scan error"),
        "detOtpQrErrorBody": MessageLookupByLibrary.simpleMessage(
            "Sorry, we could not read the QR code, please try once again or contact the app authors with error details."),
        "detOtpQrWrong": MessageLookupByLibrary.simpleMessage("Wrong QR code"),
        "detOtpQrWrongBody": MessageLookupByLibrary.simpleMessage(
            "Your QR code was successfully scanned but it doesn\'t contain one-time password data."),
        "detSetIcon": MessageLookupByLibrary.simpleMessage("Change icon"),
        "detSetupOtpManualButton":
            MessageLookupByLibrary.simpleMessage("Enter code manually"),
        "detUpdated": MessageLookupByLibrary.simpleMessage("Updated"),
        "deviceSettings":
            MessageLookupByLibrary.simpleMessage("Device Settings"),
        "disabled": MessageLookupByLibrary.simpleMessage("Disabled"),
        "discard": MessageLookupByLibrary.simpleMessage("Discard"),
        "discardChanges":
            MessageLookupByLibrary.simpleMessage("Discard changes"),
        "domain": MessageLookupByLibrary.simpleMessage("Domain"),
        "done": MessageLookupByLibrary.simpleMessage("Done"),
        "downloading": MessageLookupByLibrary.simpleMessage("Downloading"),
        "email": MessageLookupByLibrary.simpleMessage("Email"),
        "enableAutofill":
            MessageLookupByLibrary.simpleMessage("Enable Autofill"),
        "enableAutofillRequired": m3,
        "enabled": MessageLookupByLibrary.simpleMessage("Enabled"),
        "enterNewPresetName": MessageLookupByLibrary.simpleMessage(
            "Enter the new name for the preset"),
        "enterNumberBetweenXAndY": m4,
        "enterOldPassword": MessageLookupByLibrary.simpleMessage(
            "First, enter your current password."),
        "enter_your_account_password":
            MessageLookupByLibrary.simpleMessage("Enter your account password"),
        "enter_your_email_address":
            MessageLookupByLibrary.simpleMessage("Enter your email address"),
        "entryAttachmentSizeError": MessageLookupByLibrary.simpleMessage(
            "Large-sized file attachments like this one are not allowed because including them in your Vault will significantly slow down common tasks such as signing-in to your Vault and saving changes. Keep your attachments to a maximum of 250KB"),
        "entryAttachmentSizeWarning": MessageLookupByLibrary.simpleMessage(
            "Medium-sized file attachments like this one are allowed. However, including more than a small number of them in your Vault will significantly slow down common tasks such as signing-in to your Vault and saving changes. Try to keep your attachments below 20KB"),
        "entryHistory": MessageLookupByLibrary.simpleMessage("Entry history"),
        "entryHistoryExplainer": MessageLookupByLibrary.simpleMessage(
            "Old versions of this entry are listed below. If you need to revert to an older version, we will automatically add your latest saved version to this list."),
        "entryIntegrationHintNewId": MessageLookupByLibrary.simpleMessage(
            "New ID (e.g. com.example... )"),
        "entryIntegrationHintNewUrl":
            MessageLookupByLibrary.simpleMessage("New URL (include https://)"),
        "errorCorruptField": MessageLookupByLibrary.simpleMessage(
            " : A field in this entry is corrupt. Please check the \'Help > Console log\' for details."),
        "everyoneElseCanUseForFree": MessageLookupByLibrary.simpleMessage(
            "Everyone else is welcome to use the app for free without an account."),
        "exact": MessageLookupByLibrary.simpleMessage("Exact"),
        "existingUsersSignInBelow": MessageLookupByLibrary.simpleMessage(
            "If you already have a Kee Vault account on the https://keevault.pm \"Web App\" you can sign-in below."),
        "export": MessageLookupByLibrary.simpleMessage("Export"),
        "exportAnyway": MessageLookupByLibrary.simpleMessage("Export anyway"),
        "exportDirtyFileWarning": MessageLookupByLibrary.simpleMessage(
            "We export the latest saved version of your Kee Vault. You may want to save your current changes before exporting."),
        "exportError": MessageLookupByLibrary.simpleMessage("Export error"),
        "exportErrorDetails": MessageLookupByLibrary.simpleMessage(
            "Sorry, we were unable to export to this location. Please check that you have enabled the necessary permissions for Kee Vault to access the file. If you still have problems please report it on the community forum along with full details of your device so that we can investigate whether we can add support for your particular device in future."),
        "exportUsesCurrentPassword": MessageLookupByLibrary.simpleMessage(
            "Exports are encrypted and can be unlocked using the same password you use to open your Kee Vault."),
        "exported": MessageLookupByLibrary.simpleMessage("Exported"),
        "fieldName": MessageLookupByLibrary.simpleMessage("Field name"),
        "filterTooltipClosed": MessageLookupByLibrary.simpleMessage(
            "Reveal search options and other filters"),
        "filterTooltipOpen":
            MessageLookupByLibrary.simpleMessage("Show matching entries"),
        "filteredByCriteria": m5,
        "footerTitleGen": MessageLookupByLibrary.simpleMessage("Generate"),
        "forgotPasswordOrCheckAccount": MessageLookupByLibrary.simpleMessage(
            "Forgot your password or unsure if you have a Kee Vault account?"),
        "freeUserTermsPopup1": MessageLookupByLibrary.simpleMessage(
            "By using this app for free without an associated Kee Vault account, you are bound by the same terms and privacy policy as a user with an Account."),
        "freeUserTermsPopup2": MessageLookupByLibrary.simpleMessage(
            "However, some terms will obviously not be relevant to you immediately. To save time, you could skip these sections of the Terms of Service: B - Account Terms, E - Payment, F - Free Trial and G - Cancellation and Termination, although you might wish to review them anyway if you think that you may sign up for an Account one day in the future."),
        "freeUserTermsPopup3": MessageLookupByLibrary.simpleMessage(
            "You can view the documents here:"),
        "freeUserTermsPopup4": MessageLookupByLibrary.simpleMessage(
            "You will be given a further opportunity to review these documents if you later create a Kee Vault account."),
        "genLen": MessageLookupByLibrary.simpleMessage("Length"),
        "genPresetHigh": MessageLookupByLibrary.simpleMessage("High security"),
        "genPresetMac": MessageLookupByLibrary.simpleMessage("MAC address"),
        "genPresetMed": MessageLookupByLibrary.simpleMessage("Medium security"),
        "genPresetPin4": MessageLookupByLibrary.simpleMessage("4-digit PIN"),
        "genPresetPronounceable":
            MessageLookupByLibrary.simpleMessage("Pronounceable"),
        "genPresetVeryHigh":
            MessageLookupByLibrary.simpleMessage("Very high security"),
        "genPsAmbiguous":
            MessageLookupByLibrary.simpleMessage("Ambiguous symbols"),
        "genPsBrackets": MessageLookupByLibrary.simpleMessage("Brackets"),
        "genPsDefault":
            MessageLookupByLibrary.simpleMessage("Selected by default"),
        "genPsDelete": MessageLookupByLibrary.simpleMessage("Delete preset"),
        "genPsDigits": MessageLookupByLibrary.simpleMessage("Digits"),
        "genPsHigh":
            MessageLookupByLibrary.simpleMessage("High ASCII characters"),
        "genPsLower":
            MessageLookupByLibrary.simpleMessage("Lowercase latin letters"),
        "genPsSpecial": MessageLookupByLibrary.simpleMessage("Special symbols"),
        "genPsTitle": MessageLookupByLibrary.simpleMessage("Generator Presets"),
        "genPsUpper":
            MessageLookupByLibrary.simpleMessage("Uppercase latin letters"),
        "generateSinglePassword":
            MessageLookupByLibrary.simpleMessage("Generate single password"),
        "gotIt": MessageLookupByLibrary.simpleMessage("Got it"),
        "group": MessageLookupByLibrary.simpleMessage("group"),
        "groupNameNewExplanation": MessageLookupByLibrary.simpleMessage(
            "Enter the name for the new group"),
        "groupNameRenameExplanation": MessageLookupByLibrary.simpleMessage(
            "Enter the new name for the group"),
        "help": MessageLookupByLibrary.simpleMessage("Help"),
        "hexadecimal": MessageLookupByLibrary.simpleMessage("Hexadecimal"),
        "hide": MessageLookupByLibrary.simpleMessage("Hide"),
        "hostname": MessageLookupByLibrary.simpleMessage("Hostname"),
        "identifying": MessageLookupByLibrary.simpleMessage("Identifying"),
        "import": MessageLookupByLibrary.simpleMessage("Import"),
        "importComplete":
            MessageLookupByLibrary.simpleMessage("Import completed"),
        "importError": MessageLookupByLibrary.simpleMessage("Import error"),
        "importErrorDetails": MessageLookupByLibrary.simpleMessage(
            "Sorry, we were unable to import this file. Please check that it is a valid KDBX file and that you have enabled the necessary permissions for Kee Vault to access the file. If you still have problems please report it on the community forum along with full details of your device so that we can investigate whether we can add support for your particular device in future."),
        "importErrorKdbx": MessageLookupByLibrary.simpleMessage(
            "Sorry, we were unable to import this KDBX file. You probably need to save it in a different way. More details: "),
        "importExport": MessageLookupByLibrary.simpleMessage("Import / Export"),
        "importKdbx": MessageLookupByLibrary.simpleMessage(
            ".kdbx file (Kee Vault, KeePass, etc.)"),
        "importOtherInstructions1": MessageLookupByLibrary.simpleMessage(
            "We\'ll add specialised support for some other password manager storage formats in future but won\'t ever be able to directly support every one of the hundreds available."),
        "importOtherInstructions4": MessageLookupByLibrary.simpleMessage(
            "If you don\'t already have a file in the KDBX format, you could use the desktop computer version of KeePass Password Safe 2 to import from your original source, save the KDBX file and then import that here using the kdbx import option."),
        "importUnlockRequired": MessageLookupByLibrary.simpleMessage(
            "Enter your other password. This may be the old password you used on this device."),
        "importedContinueToVault":
            MessageLookupByLibrary.simpleMessage("Continue to your Vault"),
        "importedFree1": MessageLookupByLibrary.simpleMessage(
            "Thanks for signing in to a Kee Vault account. You already had a locally stored Vault on this device."),
        "importedFree2": MessageLookupByLibrary.simpleMessage(
            "We have automatically imported your local passwords to a new Group in your Kee Vault account. You may wish to rename the group or manually remove/edit the entries to resolve any duplication. You can read more about this and find more detailed instructions in "),
        "importedManual": MessageLookupByLibrary.simpleMessage(
            "We have imported your passwords to a new Group in your Kee Vault. You may wish to rename the group or manually remove/edit the entries to resolve any duplication. You can read more about this and find more detailed instructions in "),
        "incorrectFile": MessageLookupByLibrary.simpleMessage("Incorrect file"),
        "integrationSettings":
            MessageLookupByLibrary.simpleMessage("Integration settings"),
        "integrationSettingsExplainer": MessageLookupByLibrary.simpleMessage(
            "These settings help you to refine when this entry is autofilled into other apps and websites. Some settings apply only to when you use Kee on a desktop computer and others only to specific mobile platforms (such as Android, or iOS)."),
        "introFilter": MessageLookupByLibrary.simpleMessage(
            "\nFilter by group, label, colour and text"),
        "introSortYourEntries":
            MessageLookupByLibrary.simpleMessage("\nSort your entries"),
        "keeVaultFormatExplainer": MessageLookupByLibrary.simpleMessage(
            "Kee Vault uses a standard format to securely store your passwords. You are free to export your passwords in this format to create a backup of your data. You can also import additional passwords to your vault from this screen."),
        "keep": MessageLookupByLibrary.simpleMessage("Keep"),
        "keep_your_changes_question": MessageLookupByLibrary.simpleMessage(
            "Do you want to keep your changes?"),
        "label": MessageLookupByLibrary.simpleMessage("Label"),
        "labelAssignmentExplanation": MessageLookupByLibrary.simpleMessage(
            "Add new or existing labels to entries by editing the entry."),
        "labelFilteringHint": MessageLookupByLibrary.simpleMessage(
            "Select labels above to display only entries with a matching label."),
        "labels": MessageLookupByLibrary.simpleMessage("Labels"),
        "labelsExplanation": MessageLookupByLibrary.simpleMessage(
            "Labels allow you to categorise your entries."),
        "labelsExplanation2": MessageLookupByLibrary.simpleMessage(
            "Unlike Groups, each entry can be assigned more than one label."),
        "loading": MessageLookupByLibrary.simpleMessage("Loading"),
        "localOnlyAgree1":
            MessageLookupByLibrary.simpleMessage("You need to agree to the "),
        "localOnlyAgree2": MessageLookupByLibrary.simpleMessage(
            "Terms of Service and Privacy Statement"),
        "localOnlyAgree3": MessageLookupByLibrary.simpleMessage(
            ". We\'ll remember this until you uninstall the app or clear the app data. You MUST avoid clearing stored App data or you will also delete the passwords, usernames and other data you store in the app!"),
        "localOnlyAgree4": MessageLookupByLibrary.simpleMessage(
            "I understand and agree to the above"),
        "localOnlyIntro": MessageLookupByLibrary.simpleMessage(
            "Kee Vault supports one free user on your device. The passwords you store into your Vault will be held securely on only this device so you should ensure that you do not delete the App\'s Data and that you take regular backups."),
        "lock": MessageLookupByLibrary.simpleMessage("Lock"),
        "longPressGroupExplanation": MessageLookupByLibrary.simpleMessage(
            "Long-press on a group to rename, move or delete it, or to create a new subgroup."),
        "makeMoreChangesOrSave1": MessageLookupByLibrary.simpleMessage(
            "Entry updated. Don\'t forget to \"Save\" your Vault when you have finished creating and changing entries."),
        "makeMoreChangesOrSave2": MessageLookupByLibrary.simpleMessage(
            "You don\'t need to save after every change you make but make sure you save before closing the app or locking your Vault."),
        "makeMoreChangesOrSave3": MessageLookupByLibrary.simpleMessage(
            "Beware that some devices will randomly delete unsaved data if you switch to using a different app for a little while."),
        "manageAccount": MessageLookupByLibrary.simpleMessage("Manage account"),
        "manageAccountDetail": MessageLookupByLibrary.simpleMessage(
            "Manage your Kee Vault account"),
        "manageAccountSettingsDetail": MessageLookupByLibrary.simpleMessage(
            "Edit your subscription, payment details or email contact preferences from the Kee Vault Account website."),
        "managePasswordPresets":
            MessageLookupByLibrary.simpleMessage("Manage password presets"),
        "managePresets": MessageLookupByLibrary.simpleMessage("Manage presets"),
        "menuEmptyTrash": MessageLookupByLibrary.simpleMessage("Empty Bin"),
        "menuEmptyTrashAlert":
            MessageLookupByLibrary.simpleMessage("Empty Bin?"),
        "menuEmptyTrashAlertBody": MessageLookupByLibrary.simpleMessage(
            "You will not be able to get the entries back"),
        "menuSetGeneral": MessageLookupByLibrary.simpleMessage("General"),
        "menuTrash": MessageLookupByLibrary.simpleMessage("Bin"),
        "merging": MessageLookupByLibrary.simpleMessage("Merging"),
        "minURLMatchAccuracy": MessageLookupByLibrary.simpleMessage(
            "Minimum accuracy for a URL match"),
        "minURLMatchAccuracyExactWarning": MessageLookupByLibrary.simpleMessage(
            "If you select Exact (for use on desktop web browsers) we\'ll use Hostname matching on mobile instead because Android and iOS do not permit Exact matching."),
        "minimumMatchAccuracyDomainExplainer":
            MessageLookupByLibrary.simpleMessage(
                "The URL only needs to be part of the same domain to match."),
        "minimumMatchAccuracyExactExplainer": MessageLookupByLibrary.simpleMessage(
            "The URL must match exactly including full path and query string."),
        "minimumMatchAccuracyHostnameExplainer":
            MessageLookupByLibrary.simpleMessage(
                "The URL must match the hostname (domain and subdomains) and port."),
        "move": MessageLookupByLibrary.simpleMessage("Move"),
        "name": MessageLookupByLibrary.simpleMessage("name"),
        "newGroup": MessageLookupByLibrary.simpleMessage("New Group"),
        "newPassword": MessageLookupByLibrary.simpleMessage("New password"),
        "newPasswordRepeat": MessageLookupByLibrary.simpleMessage(
            "New password (please repeat)"),
        "newProfile": MessageLookupByLibrary.simpleMessage("New profile"),
        "noEntriesCreateNewInstruction": MessageLookupByLibrary.simpleMessage(
            "You have no password entries yet. Create one using the + button below. If you have passwords already stored in the standard KDBX (KeePass) format you can import them."),
        "notSignedIn": MessageLookupByLibrary.simpleMessage("Not signed in"),
        "notes": MessageLookupByLibrary.simpleMessage("Notes"),
        "offerToSave":
            MessageLookupByLibrary.simpleMessage("Offer to save passwords"),
        "openError": MessageLookupByLibrary.simpleMessage("Error"),
        "openLogConsole":
            MessageLookupByLibrary.simpleMessage("Open log console"),
        "openSettings": MessageLookupByLibrary.simpleMessage("Open settings"),
        "openUrl": MessageLookupByLibrary.simpleMessage("URL"),
        "openWebApp": MessageLookupByLibrary.simpleMessage(
            "Open Kee Vault in your browser"),
        "opening": MessageLookupByLibrary.simpleMessage("Opening"),
        "otp": MessageLookupByLibrary.simpleMessage("OTP"),
        "otpCodeLabel":
            MessageLookupByLibrary.simpleMessage("TOTP code (base32 format)"),
        "otpExplainer1": MessageLookupByLibrary.simpleMessage(
            "\"One Time Passwords\" (OTP) are a feature some websites offer to improve security. It is a type of Two/Multi Factor Authentication (2FA/MFA)."),
        "otpManualError":
            MessageLookupByLibrary.simpleMessage("Invalid TOTP code"),
        "otpManualErrorBody": MessageLookupByLibrary.simpleMessage(
            "You did not enter a valid TOTP base32 code. Please try again."),
        "otpManualTitle": MessageLookupByLibrary.simpleMessage(
            "Time-based One Time Password"),
        "password": MessageLookupByLibrary.simpleMessage("Password"),
        "passwordChanged": MessageLookupByLibrary.simpleMessage(
            "Password changed. Use it when you next unlock Kee Vault."),
        "permanentlyDeleteGroupConfirm": MessageLookupByLibrary.simpleMessage(
            "Permanently delete the group and all entries within it?"),
        "permissionDeniedError": m6,
        "permissionDeniedPermanentlyError": m7,
        "permissionError":
            MessageLookupByLibrary.simpleMessage("Permission error"),
        "permissionReasonAttachFile":
            MessageLookupByLibrary.simpleMessage("attach a file"),
        "permissionReasonScanBarcodes": MessageLookupByLibrary.simpleMessage(
            "quickly scan QR codes (barcodes)"),
        "permissionSettingsOpenError": MessageLookupByLibrary.simpleMessage(
            "Sorry, your device did not allow us to open the settings for this app. Please use your device settings app to find and change the permissions settings for Kee Vault and then return here to try again."),
        "prcRegistrationError": MessageLookupByLibrary.simpleMessage(
            "Sorry, we weren\'t able to register your email address now. Please check that you have a good network connection and try again or ask for help on the community forum if the problem continues."),
        "prcRegistrationPrivacy1": MessageLookupByLibrary.simpleMessage(
            "The same privacy policy applies as when you started using the app. In brief, we\'ll protect (encrypt) your email address when we store it and will never share it or use it for anything you haven\'t agreed to. You can unsubscribe easily from each email we send to you."),
        "prcRegistrationPrivacy2": MessageLookupByLibrary.simpleMessage(
            "You can review the full policy here:"),
        "prcRegistrationSignUpButton":
            MessageLookupByLibrary.simpleMessage("Sign up to receive emails"),
        "prcRegistrationSuccess": MessageLookupByLibrary.simpleMessage(
            "Success! Please check your emails soon to confirm that you want to receive updates from us."),
        "prcSignupOrAccountStatusCheck": m8,
        "preset": MessageLookupByLibrary.simpleMessage("Preset"),
        "privacyStatement":
            MessageLookupByLibrary.simpleMessage("Privacy Statement"),
        "protectField": MessageLookupByLibrary.simpleMessage("Protect field"),
        "protectedClickToReveal": MessageLookupByLibrary.simpleMessage(
            "Protected field. Click to reveal."),
        "reenterYourPassword": MessageLookupByLibrary.simpleMessage(
            "Please re-enter your password"),
        "registrationBlurb1": MessageLookupByLibrary.simpleMessage(
            "Choose a very secure password to protect your Kee Vault. Only you will know this password - it never leaves your device. It can not be reset. You must remember it. You can change it in future."),
        "rememberExportsDoNotUpdate": MessageLookupByLibrary.simpleMessage(
            "Remember that Exports do not automatically update. The information stored within and the password required to unlock it does not change after you create the export."),
        "rememberFilterGroup": MessageLookupByLibrary.simpleMessage(
            "Remember chosen filter group"),
        "rememberVaultPassword": MessageLookupByLibrary.simpleMessage(
            "Remember your Vault password?"),
        "renameFieldEnterNewName": MessageLookupByLibrary.simpleMessage(
            "Enter the new name for the field"),
        "renamingField": MessageLookupByLibrary.simpleMessage("Renaming field"),
        "renamingPreset":
            MessageLookupByLibrary.simpleMessage("Renaming preset"),
        "requireFullPasswordEvery": MessageLookupByLibrary.simpleMessage(
            "Require full password every (days)"),
        "resetEntryToThis":
            MessageLookupByLibrary.simpleMessage("Reset entry to this state"),
        "resetPasswordInstructions": MessageLookupByLibrary.simpleMessage(
            "You can reset your password using the Kee Vault \"Web App\" (version 1)."),
        "restartSubscription":
            MessageLookupByLibrary.simpleMessage("Restart subscription"),
        "restore": MessageLookupByLibrary.simpleMessage("Restore"),
        "revertUnsavedWarning": MessageLookupByLibrary.simpleMessage(
            "Your unsaved changes will be permanently lost if you change to this older version now. Do you want to discard your changes?"),
        "save": MessageLookupByLibrary.simpleMessage("Save"),
        "saveChanges": MessageLookupByLibrary.simpleMessage("Confirm changes"),
        "saveExplainerAlertTitle":
            MessageLookupByLibrary.simpleMessage("Saving..."),
        "search": MessageLookupByLibrary.simpleMessage("Search"),
        "searchCase": MessageLookupByLibrary.simpleMessage("Match case"),
        "searchHistory":
            MessageLookupByLibrary.simpleMessage("Include entry history"),
        "searchOtherSecure":
            MessageLookupByLibrary.simpleMessage("Other protected fields"),
        "searchOtherStandard":
            MessageLookupByLibrary.simpleMessage("Other standard fields"),
        "searchRegex": MessageLookupByLibrary.simpleMessage("RegEx"),
        "searchSearchIn": MessageLookupByLibrary.simpleMessage(
            "Search in these entry fields:"),
        "selectKdbxFile":
            MessageLookupByLibrary.simpleMessage("Please select a KDBX file."),
        "serverMITMWarning": MessageLookupByLibrary.simpleMessage(
            "Sign in failed because the response we received from the server indicates that it may be compromised. The most likely explanation is that someone near you or at your internet service provider is attempting to interfere with the secure connection and connect you to a malicious server (A Miscreant In The Middle attack). Find a different internet connection immediately, shut down the Kee Vault app and try again. If it keeps happening, your local device may be compromised. The security of your Kee Vault remains intact so you need not panic. More information about the error is available at https://forum.kee.pm/"),
        "setDefault": MessageLookupByLibrary.simpleMessage("Set as default"),
        "setFilePassNotMatch": MessageLookupByLibrary.simpleMessage(
            "Passwords don\'t match, please type them again"),
        "setGenShowSubgroups": MessageLookupByLibrary.simpleMessage(
            "Show entries from all subgroups"),
        "setGenTheme": MessageLookupByLibrary.simpleMessage("Theme"),
        "setGenThemeDk": MessageLookupByLibrary.simpleMessage("Dark"),
        "setGenThemeLt": MessageLookupByLibrary.simpleMessage("Light"),
        "setGenTitlebarStyleDefault":
            MessageLookupByLibrary.simpleMessage("Default"),
        "settings": MessageLookupByLibrary.simpleMessage("Settings"),
        "share": MessageLookupByLibrary.simpleMessage("Share"),
        "show": MessageLookupByLibrary.simpleMessage("Show"),
        "showEntryInBrowsersAndApps": MessageLookupByLibrary.simpleMessage(
            "Show this entry in Kee browser extension (desktop), mobile apps and browsers"),
        "showProtectedField":
            MessageLookupByLibrary.simpleMessage("Show protected field"),
        "showing_all_entries":
            MessageLookupByLibrary.simpleMessage("Showing all entries"),
        "signin": MessageLookupByLibrary.simpleMessage("Sign in"),
        "signout": MessageLookupByLibrary.simpleMessage("Sign out"),
        "sizeBytes": m9,
        "sortCreated": MessageLookupByLibrary.simpleMessage("Newest"),
        "sortCreatedReversed": MessageLookupByLibrary.simpleMessage("Oldest"),
        "sortModified":
            MessageLookupByLibrary.simpleMessage("Recently updated"),
        "sortModifiedReversed":
            MessageLookupByLibrary.simpleMessage("Least recently updated"),
        "sortTitle": MessageLookupByLibrary.simpleMessage("Title"),
        "sortTitleReversed":
            MessageLookupByLibrary.simpleMessage("Title - reversed"),
        "startAccountReset":
            MessageLookupByLibrary.simpleMessage("Start account reset"),
        "startFreeTrial":
            MessageLookupByLibrary.simpleMessage("Start free trial"),
        "startNewTrialError": MessageLookupByLibrary.simpleMessage(
            "Sorry, we weren\'t able to restart your trial now. Please try again later and ask for help on the community forum if the problem continues."),
        "startNewTrialSuccess":
            MessageLookupByLibrary.simpleMessage("All done!"),
        "subscriptionExpired":
            MessageLookupByLibrary.simpleMessage("Subscription expired"),
        "subscriptionExpiredDetails": MessageLookupByLibrary.simpleMessage(
            "Your subscription or trial period has ended. Provide up to date payment details and re-enable your subscription on the Kee Vault Account Management web site."),
        "subscriptionExpiredTrialAvailable": MessageLookupByLibrary.simpleMessage(
            "Welcome back to Kee Vault. You can enable a new 30 day free trial to see what has improved since you first created your Kee Vault account."),
        "tagRename": MessageLookupByLibrary.simpleMessage("Rename"),
        "text": MessageLookupByLibrary.simpleMessage("Text"),
        "textFilteringHint": MessageLookupByLibrary.simpleMessage(
            "These options change how Search uses your text input to find entries."),
        "thisCommunityForumTopic":
            MessageLookupByLibrary.simpleMessage("this community forum topic"),
        "this_field_required":
            MessageLookupByLibrary.simpleMessage("This field is required"),
        "title": MessageLookupByLibrary.simpleMessage("title"),
        "tryAgain": MessageLookupByLibrary.simpleMessage("Try again"),
        "unexpected_error": m10,
        "unlock": MessageLookupByLibrary.simpleMessage("Unlock"),
        "unlockRequired":
            MessageLookupByLibrary.simpleMessage("Unlock your Vault"),
        "unlock_with_biometrics":
            MessageLookupByLibrary.simpleMessage("Use biometrics"),
        "unprotectField":
            MessageLookupByLibrary.simpleMessage("Unprotect field"),
        "useWebAppForOtherSettings": MessageLookupByLibrary.simpleMessage(
            "You can change your account password and some additional settings from the Kee Vault web app by using your web browser to sign in to Kee Vault."),
        "user": MessageLookupByLibrary.simpleMessage("user"),
        "userEmail": MessageLookupByLibrary.simpleMessage("User/Email"),
        "vaultStatusActionNeeded":
            MessageLookupByLibrary.simpleMessage("Action needed"),
        "vaultStatusDescLoaded": MessageLookupByLibrary.simpleMessage(
            "Your Vault is loaded and ready for use."),
        "vaultStatusDescMerging": MessageLookupByLibrary.simpleMessage(
            "Merging your changes from your other devices"),
        "vaultStatusDescPasswordChanged":
            MessageLookupByLibrary.simpleMessage("Your password has changed"),
        "vaultStatusDescRefreshing": MessageLookupByLibrary.simpleMessage(
            "Checking for changes from your other devices"),
        "vaultStatusDescSaveNeeded": MessageLookupByLibrary.simpleMessage(
            "There are changes from other devices which will be merged with this device when you next save."),
        "vaultStatusDescSaving":
            MessageLookupByLibrary.simpleMessage("Saving your changes"),
        "vaultStatusDescUnknown": MessageLookupByLibrary.simpleMessage(
            "If this situation does not automatically resolve itself within a minute, please check the Console Log in the Help section, report the problem and restart the app."),
        "vaultStatusDescUploading":
            MessageLookupByLibrary.simpleMessage("Uploading your changes"),
        "vaultStatusError": MessageLookupByLibrary.simpleMessage("Error"),
        "vaultStatusLoaded": MessageLookupByLibrary.simpleMessage("Loaded"),
        "vaultStatusRefreshing":
            MessageLookupByLibrary.simpleMessage("Refreshing"),
        "vaultStatusSaveNeeded":
            MessageLookupByLibrary.simpleMessage("Save needed"),
        "vaultStatusSaving": MessageLookupByLibrary.simpleMessage("Saving"),
        "vaultStatusUnknownState":
            MessageLookupByLibrary.simpleMessage("Unknown state"),
        "vaultStatusUploading":
            MessageLookupByLibrary.simpleMessage("Uploading"),
        "vaultTooLarge": MessageLookupByLibrary.simpleMessage(
            "Your Kee Vault is too large to save and sync to other devices. Delete some large file attachments, empty the bin, etc. and then try again."),
        "visitTheForum":
            MessageLookupByLibrary.simpleMessage("Visit the forum"),
        "website": MessageLookupByLibrary.simpleMessage("Website"),
        "welcomeToKeeVault":
            MessageLookupByLibrary.simpleMessage("Welcome to Kee Vault"),
        "welcome_message": m11,
        "willTrySamePasswordFirst": MessageLookupByLibrary.simpleMessage(
            "We\'ll try using the same password you have used to open your current Kee Vault. If that doesn\'t work, you can type in the correct password in a moment."),
        "yourPasswordEntries":
            MessageLookupByLibrary.simpleMessage("Your password entries")
      };
}
