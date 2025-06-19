import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:keevault/config/app.dart';
import 'package:keevault/widgets/dialog_utils.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import 'package:rate_my_app/rate_my_app.dart';
import '../config/platform.dart';
import '../logging/logger.dart';

part 'app_rating_state.dart';

class AppRatingCubit extends Cubit<AppRatingState> {
  AppRatingCubit() : super(AppRatingInitial()) {
    unawaited(start());
  }

  late RateMyApp _rateMyApp;
  Future<void> start() async {
    l.d('starting app rating cubit');
    _rateMyApp = RateMyApp(
      preferencesPrefix: 'rateMyAppKV_',
      minDays: 60,
      minLaunches: 20,
      remindDays: 60,
      remindLaunches: 15,
      googlePlayIdentifier: 'com.keevault.keevault',
      appStoreIdentifier: '1640663427',
    );
    await _rateMyApp.init();
    emit(AppRatingReady());
  }

  Future<void> showRatingDialog(BuildContext context, {num initialStars = 0}) async {
    trackEvent('ratingDisplayed', value: initialStars);
    await _rateMyApp.showStarRateDialog(
      context,
      title: 'Rate Kee Vault',
      message:
          'How happy are you with Kee Vault so far?\n\n1 star means it\'s terrible and 5 stars means it\'s very good.',
      // contentBuilder: (context, defaultContent) => content, // This one allows you to change the default dialog content.
      actionsBuilder: (context, stars) {
        // Triggered when the user updates the star rating.
        return [
          TextButton(
            child: Text('CANCEL'),
            onPressed: () async {
              Navigator.pop<RateMyAppDialogButton>(context, RateMyAppDialogButton.rate);
            },
          ),
          TextButton(
            onPressed: stars != null && stars > 0
                ? () async {
                    final starInt = stars.round();
                    trackEvent('rated', value: starInt);
                    await _rateMyApp.callEvent(RateMyAppEventType.rateButtonPressed);
                    if (!context.mounted) return;
                    Navigator.pop<RateMyAppDialogButton>(context, RateMyAppDialogButton.rate);
                    unawaited(starInt < 5 ? showForumDialog(starInt) : showStoreLoadDialog());
                  }
                : null,
            child: Text('CONTINUE'),
          ),
        ];
      },
      ignoreNativeDialog: true,
      dialogStyle: const DialogStyle(
        // Custom dialog styles.
        titleAlign: TextAlign.center,
        messageAlign: TextAlign.center,
        messagePadding: EdgeInsets.only(bottom: 20),
      ),
      starRatingOptions: StarRatingOptions(initialRating: initialStars.toDouble()),
      onDismissed: () => _rateMyApp.callEvent(
        RateMyAppEventType.laterButtonPressed,
      ), // Called when the user dismissed the dialog (either by taping outside or by pressing the "back" button).
    );
  }

  void trackEvent(String action, {String? name, num? value}) {
    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(category: 'rating', name: name, action: action, value: value),
    );
  }

  Future<void> showForumDialog(num stars) async {
    final result = await DialogUtils.showIgnorableConfirmDialog(
      context: AppConfig.navigatorKey.currentContext!,
      params: ConfirmDialogParams(
        content:
            'We\'re sorry to hear that Kee Vault is not yet a 5 star experience for you.\n\nSharing your feedback with our community really helps us to keep Kee Vault improving. Our community forum also contains a variety of documentation topics and previously answered questions which might help to improve your experience.',
        negativeButtonText: 'BACK',
        positiveButtonText: 'Visit forum'.toUpperCase(),
        title: 'How can we improve?',
      ),
    );

    if (result == true) {
      trackEvent('forumLaunched', value: stars);
      await DialogUtils.openUrl('https://forum.kee.pm/c/kee-vault/9');
    } else if (result == false) {
      trackEvent('backToRatingDialog', value: stars);
      await showRatingDialog(AppConfig.navigatorKey.currentContext!, initialStars: stars);
    } else {
      trackEvent('forumDismissed', value: stars);
    }
  }

  Future<void> showStoreLoadDialog() async {
    final result = await DialogUtils.showConfirmDialog(
      context: AppConfig.navigatorKey.currentContext!,
      params: ConfirmDialogParams(
        content:
            'Glad to hear you\'re happy! Sharing your 5 star rating and an optional review comment on ${KeeVaultPlatform.isAndroid ? 'Google Play' : 'the App Store'} really helps us to keep Kee Vault improving.\n\nCan you spare a minute to do this?',
        negativeButtonText: 'NO',
        positiveButtonText: 'Yes, I\'ll help'.toUpperCase(),
        title: 'Share the love?',
      ),
    );

    if (result) {
      final launchResult = await _rateMyApp.launchStore();
      l.d('launchResult: $launchResult');
      trackEvent('storeLaunchAttempted', value: launchResult.index);
    } else {
      trackEvent('storeLaunchDismissed');
    }
  }
}
