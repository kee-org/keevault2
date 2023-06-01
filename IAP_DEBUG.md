Google and Apple restrictions mean that we can't debug In App Purchases and new user registration using the usual development version of the app.

Instead, we must temporarily hack a few configuration points so that when launching in debug mode we assume the identity of the production app. Naturally, this app can only be executed on development devices since it has no valid certificates/signing for distribution.

To perform this hack rebase and then apply the HEAD commit of the iap-debug-hack branch.

Make sure to debug using the appropriate VScode launch task - e.g. "keevault IAP hack debug"
