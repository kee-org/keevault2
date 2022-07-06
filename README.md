# Kee Vault 2

[![Open in Visual Studio Code](https://open.vscode.dev/badges/open-in-vscode.svg)](https://open.vscode.dev/kee-org/keevault2)

Kee Vault 2 is a password manager for multiple devices. Password databases (Vaults) are encrypted using the KeePass storage format (KDBX) before being stored on the local device or sent to a remote server for synchronisation purposes.

The optional paid subscription service to enable synchronisation (among other benefits and morally good feelings) is fully compatible with the first version of Kee Vault so version 1 and 2 can be used interchangeably depending upon your specific requirements.

We offer an Android and iOS version of Kee Vault 2 but the underlying development platform (Flutter) should allow us to release versions in the future for desktop devices and/or fully replace the web app version (Kee Vault v1).

To subscribe to the Kee Vault service or view the code for version 1, see the https://github.com/kee-org/keevault repository.

Support questions, bug reports, feature requests and general feedback about the software or service should be raised and discussed in our community at https://forum.kee.pm - we'll use GitHub issues only for specific pre-approved issues at the moment so will most likely close your issue without review or comment if you initially raise an issue here.

# Code quality

There are a number of "//TODO:f:" comments across the code at launch. We'll either address these in future, remove them when no longer relevant, or transcribe them into more detailed GitHub issues when time permits. They are a mixture of ideas for future improvements and reminders to improve the code when possible or investigate some uncertainties in more detail.

There are some aspects of Dart/Flutter development that are or were imperfect as of the time we worked on some areas of the app and some of the early work in 2019 might not be considered perfect practice by now. That said, we follow the latest lint guidelines and try to keep warnings and exceptions to a minimum so it shouldn't be too hard to work out what is going on.

Other than that, the initial release of the code should be of pretty high quality overall. We'd welcome any suggestions for improvements, ideally via the discussion forum first rather than a PR, unless you're happy to take a punt on the suggestion being accepted for incorporation to the project.

# License

[AGPL3 with permitted extra clauses](https://github.com/kee-org/keevault/blob/master/LICENSE)