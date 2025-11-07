import 'dart:async';

import 'package:collection/collection.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inapp_purchase/modules.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/config/platform.dart';
import 'package:keevault/vault_backend/exceptions.dart';

import 'package:keevault/vault_backend/user.dart';

import '../config/app.dart';
import '../config/routes.dart';
import '../cubit/account_cubit.dart';
import '../cubit/vault_cubit.dart';
import '../generated/l10n.dart';
import '../logging/logger.dart';
import '../payment_service.dart';
import '../widgets/password_strength.dart';
import 'blocking_overlay.dart';
import 'coloured_safe_area_widget.dart';
import 'subscriber_terms_dialog.dart';

class IapDetails {
  List<IAPItem> products;
  int offerTokenIndex;
  bool trialAvailable;
  String? formattedPrice;
  IapDetails({
    required this.products,
    required this.offerTokenIndex,
    required this.trialAvailable,
    required this.formattedPrice,
  });
}

class AccountCreateWidget extends StatefulWidget {
  const AccountCreateWidget({super.key, this.emailAddress});

  final String? emailAddress;

  @override
  State<AccountCreateWidget> createState() => _AccountCreateWidgetState();
}

class _AccountCreateWidgetState extends State<AccountCreateWidget> {
  final _formKey = GlobalKey<FormState>();
  String? submittedPassword;
  String? submittedEmail;
  final TextEditingController _emailAddress = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  late bool saveError;
  late bool saving;
  bool? hasFreeKdbx;
  bool marketingPreference = false;
  bool agreedToS = false;
  IapDetails? iap;
  bool password1Obscured = true;
  bool password2Obscured = true;

  String? registrationErrorMessage;

  Function(PurchasedItem)? purchaseListenerCallback;

  @override
  void initState() {
    super.initState();
    saving = false;
    saveError = false;
    if (widget.emailAddress?.isNotEmpty ?? false) {
      _emailAddress.text = widget.emailAddress!;
    }
    unawaited(_detectFreeKdbx());
    unawaited(initialiseIAP());
  }

  @override
  void dispose() {
    if (purchaseListenerCallback != null) {
      PaymentService.instance.removeFromPurchasedListeners(purchaseListenerCallback!);
    }
    super.dispose();
  }

  Future<void> _detectFreeKdbx() async {
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    final localFreeKdbxExists = await vaultCubit.localFreeKdbxExists();
    setState(() {
      hasFreeKdbx = localFreeKdbxExists;
    });
  }

  Future<void> handlePurchaseItem(
    PurchasedItem item,
    bool isAndroid,
    BlockingOverlayState blockingOverlay,
    AccountCubit accountCubit,
    VaultCubit vaultCubit,
    str,
  ) async {
    final customMessage = Center(
      child: SizedBox(
        child: Material(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(padding: const EdgeInsets.all(16.0), child: Text(str.subscriptionAssociatingDescription)),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(8.0),
                  child: const CircularProgressIndicator(strokeWidth: 4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    blockingOverlay.show(customMessage, Duration(seconds: 0));
    final retry = await accountCubit.subscriptionSuccess(
      item,
      isAndroid,
      () => vaultCubit.ensureRemoteCreated(accountCubit.currentUser, submittedPassword),
      () async {
        try {
          return PaymentService.instance.finishTransaction(item);
        } on Exception catch (e) {
          l.w(
            'Exception while finishing the payment transaction. Ignoring but an app restart and/or a fresh sign-in or registration attempt may be required for everything to catch up. May also require a few minutes for server-side operations to complete.',
            error: e,
          );
        }
      },
    );
    if (retry) {
      try {
        await PaymentService.instance.buyProduct(iap!.products[0], iap!.offerTokenIndex);
        return;
      } on Exception {
        if (mounted) {
          setState(() {
            saving = false;
          });
        }
      }
    }
    blockingOverlay.hide();
  }

  Future<void> initialiseIAP() async {
    final accountCubit = BlocProvider.of<AccountCubit>(context);
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    final blockingOverlay = BlockingOverlay.of(context);
    final iapReady = await PaymentService.instance.ensureReady();
    List<IAPItem> prods = [];

    attachIapListeners() {
      PaymentService.instance.addToErrorListeners((msg) {
        accountCubit.subscriptionError(msg);
        blockingOverlay.hide();
      });
      purchaseListenerCallback = (item) async {
        if (item.purchaseToken == null && item.transactionReceipt == null) {
          return;
        }
        if (accountCubit.state is AccountSubscribing) {
          final str = S.current;
          await handlePurchaseItem(
            item,
            item.purchaseStateAndroid != null,
            blockingOverlay,
            accountCubit,
            vaultCubit,
            str,
          );
        } else {
          // We're not expecting this purchase so we will defer it until the user has navigated to a point where we can do something useful with it (e.g. either creating a new account or exiting and signing in again with fresh authentication tokens)
          PaymentService.instance.deferPurchaseItem(item);
        }
      };
      PaymentService.instance.addToPurchasedListeners(purchaseListenerCallback!);
    }

    if (iapReady) {
      prods = await PaymentService.instance.products;
      if (prods.isNotEmpty) {
        if (KeeVaultPlatform.isIOS) {
          attachIapListeners();

          setState(() {
            iap = IapDetails(
              products: prods,
              offerTokenIndex: -1,
              trialAvailable: true, // Apple don't permit us to know this information so we show the more general text
              formattedPrice: prods[0].localizedPrice,
            );
          });
          return;
        }
        if (KeeVaultPlatform.isAndroid) {
          final trialProductIndex =
              prods[0].subscriptionOffersAndroid?.indexWhere((o) => o.offerId == 'supporter-yearly-trial') ?? -1;
          final selectedProductIndex = trialProductIndex >= 0
              ? trialProductIndex
              : prods[0].subscriptionOffersAndroid?.indexWhere((o) => o.basePlanId == 'supporter-yearly') ?? -1;
          final selectedProduct = selectedProductIndex >= 0
              ? (prods[0].subscriptionOffersAndroid![selectedProductIndex])
              : null;

          if (selectedProduct != null) {
            final pricingIndex = selectedProduct.pricingPhases?.indexWhere((p) => p.recurrenceMode == 1) ?? -1;
            final price = pricingIndex >= 0 ? selectedProduct.pricingPhases![pricingIndex].formattedPrice : null;
            attachIapListeners();

            setState(() {
              iap = IapDetails(
                products: prods,
                offerTokenIndex: selectedProductIndex,
                trialAvailable: trialProductIndex >= 0,
                formattedPrice: price,
              );
            });
            return;
          }
        }
      }
    }

    // Something has gone wrong at Store level so we have to inform user purchases are not available.
    // Easiest way is by using absence of any known price so we check for formattedPrice == null
    l.d('no IAP products available');
    setState(() {
      iap = IapDetails(products: [], offerTokenIndex: 0, trialAvailable: false, formattedPrice: null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    final linkColor = theme.brightness == Brightness.dark ? theme.colorScheme.secondary : theme.colorScheme.primary;
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) {
        if (state is AccountSubscribed) {
          return AccountCreateWrapperWidget(
            skipBackCheck: false,
            saving: false,
            widget: widget,
            mainContent: hasFreeKdbx ?? false
                ? Center(
                    child: SizedBox(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Thanks for subscribing. The last step is to transfer the items in your free vault to your new subscription. Depending upon your current preferences, you might later be asked to authenticate with biometrics or your free vault password.',
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: FilledButton(
                              onPressed: () async {
                                // During development we repeatedly hit this branch because
                                // we do not check whether the free kdbx has been imported
                                // yet or not. Assumption is that in real world, user will
                                // never repeat this account creation process but might
                                // happen within 90 days if we ever enable monthly subscriptions
                                // I guess. Still, only impact is that they are given a
                                // confusing button to press and nothing breaks.

                                final accountCubit = BlocProvider.of<AccountCubit>(context);
                                await accountCubit.finaliseRegistration(state.user);
                                await AppConfig.router.navigateTo(
                                  AppConfig.navigatorKey.currentContext!,
                                  Routes.root,
                                  clearStack: true,
                                );
                              },
                              child: Text('Start import'),
                            ),
                          ),
                          Text(
                            'You can easily delete the transferred items in a moment if you are looking for a clean slate.',
                          ),
                        ],
                      ),
                    ),
                  )
                : Center(
                    child: SizedBox(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('Welcome! Thanks for subscribing.'),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: FilledButton(
                              onPressed: () async {
                                final accountCubit = BlocProvider.of<AccountCubit>(context);
                                await accountCubit.finaliseRegistration(state.user);
                                await AppConfig.router.navigateTo(
                                  AppConfig.navigatorKey.currentContext!,
                                  Routes.root,
                                  clearStack: true,
                                );
                              },
                              child: Text('Go to your Vault'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            mainTitle: 'Subscribe',
          );
        } else if (state is AccountAuthenticated && state is! AccountSubscribing) {
          final reasonText = resubscriptionNeededReason(state);
          final pricingText = pricingTextRenewal();
          final renewalWidgets = isRenewalMode(state)
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(pricingText, style: theme.textTheme.titleMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall,
                        children: <TextSpan>[
                          TextSpan(text: 'You have already agreed to our '),
                          TextSpan(
                            text: str.localOnlyAgree2,
                            style: theme.textTheme.bodyMedium!.copyWith(color: linkColor, fontWeight: FontWeight.bold),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                await SubscriberTermsDialog().show(context);
                              },
                          ),
                          TextSpan(
                            text:
                                '. You should recall that if your subscription has been expired for less than approximately 6 months, we may backdate any new subscription to the time that one expired, so that we can recover your protected password data.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ]
              : [];
          final actionButton = state is AccountSubscribeError
              ? FilledButton(
                  onPressed: () async {
                    // sign out so user can see initial signin/register page again.
                    final vc = BlocProvider.of<VaultCubit>(context);
                    await BlocProvider.of<AccountCubit>(context).forgetUser(vc.signout);
                    await AppConfig.router.navigateTo(
                      AppConfig.navigatorKey.currentContext!,
                      Routes.root,
                      clearStack: true,
                    );
                  },
                  child: Text('Sign in'),
                )
              : FilledButton(
                  onPressed: saving || iap == null || iap!.formattedPrice == null
                      ? null
                      : () async {
                          setState(() {
                            saveError = false;
                            saving = true;
                          });
                          try {
                            await subscribeUser(state.user);
                            setState(() {
                              saving = false;
                            });
                          } on Exception {
                            setState(() {
                              saving = false;
                              saveError = true;
                            });
                          }
                        },
                  child: saving
                      ? Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(2.0),
                          child: const CircularProgressIndicator(strokeWidth: 3),
                        )
                      : Text('Subscribe now'),
                );
          return AccountCreateWrapperWidget(
            widget: widget,
            skipBackCheck: true,
            saving: false,
            mainContent: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(reasonText, style: theme.textTheme.titleLarge),
                ),
                ...renewalWidgets,
                Align(alignment: Alignment.center, child: actionButton),
              ],
            ),
            mainTitle: 'Subscribe',
          );
        } else {
          return AccountCreateWrapperWidget(
            skipBackCheck: saveError || (registrationErrorMessage?.isNotEmpty ?? false),
            saving: saving,
            widget: widget,
            mainContent: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'Use Kee Vault on multiple devices, including any web browser and protect yourself from device loss/failure!',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
                      child: TextFormField(
                        controller: _emailAddress,
                        obscureText: false,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: str.email,
                          hintText: str.enter_your_email_address,
                          errorText: null,
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? false) {
                            return str.this_field_required;
                          }
                          return !EmailValidator.validate(value ?? '') ? str.emailValidationFail : null;
                        },
                        onSaved: (String? value) {
                          submittedEmail = value;
                        },
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(pricingText(), style: theme.textTheme.titleMedium),
                    ),
                    Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Text(str.registrationBlurb1)),
                    Visibility(
                      visible: hasFreeKdbx ?? false,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          'Tip: Using the password you chose for your free Vault is simpler but not mandatory.',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextFormField(
                        controller: _password,
                        obscureText: password1Obscured,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: str.password,
                          errorText: null,
                          suffixIcon: IconButton(
                            icon: Icon(password1Obscured ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                password1Obscured = !password1Obscured;
                              });
                            },
                          ),
                          //  suffixIconColor: theme.brightness == Brightness.light ? theme.primaryColor : Colors.white,
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? false) {
                            return str.this_field_required;
                          }
                          return null;
                        },
                        keyboardType: TextInputType.visiblePassword,
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _password,
                      builder: (context, TextEditingValue content, child) {
                        return PasswordStrengthWidget(testValue: content.text);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: TextFormField(
                        controller: _confirmPassword,
                        obscureText: password2Obscured,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: str.passwordRepeat,
                          suffixIcon: IconButton(
                            icon: Icon(password2Obscured ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                password2Obscured = !password2Obscured;
                              });
                            },
                          ),
                          // suffixIconColor: theme.brightness == Brightness.light ? theme.primaryColor : Colors.white,
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? false) {
                            return str.this_field_required;
                          }
                          if (value != _password.text) {
                            return str.setFilePassNotMatch;
                          }
                          return null;
                        },
                        onSaved: (String? value) {
                          submittedPassword = value;
                        },
                        keyboardType: TextInputType.visiblePassword,
                      ),
                    ),
                    Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Text(str.registrationEmailUsage1)),
                    CheckboxListTile(
                      value: marketingPreference,
                      title: Text(str.occasionalNotifications, style: theme.textTheme.labelLarge),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onChanged: (bool? value) {
                        setState(() {
                          marketingPreference = value!;
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium,
                          children: <TextSpan>[
                            TextSpan(text: str.localOnlyAgree1),
                            TextSpan(
                              text: str.localOnlyAgree2,
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: linkColor,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () async {
                                  await SubscriberTermsDialog().show(context);
                                },
                            ),
                          ],
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      value: agreedToS,
                      title: Text(str.localOnlyAgree4, style: theme.textTheme.labelLarge),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onChanged: (bool? value) {
                        setState(() {
                          agreedToS = value!;
                        });
                      },
                    ),
                    Visibility(
                      visible: saveError,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          registrationErrorMessage ??
                              'There was a problem creating your account. Please try again in a moment when you have a more stable network connection.',
                          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: FilledButton(
                        onPressed: saving || !agreedToS || iap == null || iap!.formattedPrice == null
                            ? null
                            : () async {
                                setState(() {
                                  saveError = false;
                                  registrationErrorMessage = null;
                                });
                                if (_formKey.currentState!.validate()) {
                                  setState(() {
                                    saving = true;
                                  });
                                  _formKey.currentState!.save();
                                  try {
                                    await registerAccount(submittedEmail!, submittedPassword!, marketingPreference);
                                    setState(() {
                                      saving = false;
                                    });
                                  } on Exception {
                                    setState(() {
                                      saving = false;
                                      saveError = true;
                                    });
                                  }
                                }
                              },
                        child: saving
                            ? Container(
                                width: 24,
                                height: 24,
                                padding: const EdgeInsets.all(2.0),
                                child: const CircularProgressIndicator(strokeWidth: 3),
                              )
                            : Text('Subscribe now'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            mainTitle: 'Subscribe',
          );
        }
      },
    );
  }

  String pricingText() {
    if (iap == null) {
      return "We're working out the pricing details for your local currency, sales tax, etc. Just a second...";
    }
    if (iap!.formattedPrice == null) {
      return "Unfortunately, we can't offer you a subscription directly from this device. Please try https://keevault.pm for alternative subscription offers and then sign in to this device using the account you create there.";
    }
    if (PaymentService.instance.activePurchaseItem != null) {
      return 'We found a Kee Vault subscription on this device. We will attach it to the new Kee Vault account that you are creating, provided that it has never been previously attached to a different Kee Vault account.';
    }
    return 'The Kee Vault service ${iap!.trialAvailable ? 'is free to try for the first month but ' : ''}does cost us money to run so we request a small contribution of ${iap!.formattedPrice} per year.';
  }

  String pricingTextRenewal() {
    if (iap == null) {
      return "We're working out the pricing details for your local currency, sales tax, etc. Just a second...";
    }
    if (iap!.formattedPrice == null) {
      return "Unfortunately, we can't offer you a subscription directly from this device. Please try https://keevault.pm for alternative subscription offers and then sign in to this device using the account you create there.";
    }
    return "You should be charged ${iap?.formattedPrice} but you'll have an opportunity to check this after you click the Subscribe button.";
  }

  bool checkCurrentPassword(String? value) {
    if (value == null) {
      return false;
    }
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    final currentHash = vaultCubit.currentVaultFile!.files.current.credentials.getHash();
    final newHash = Credentials(ProtectedValue.fromString(value)).getHash();
    if (ListEquality().equals(newHash, currentHash)) {
      return true;
    }
    return false;
  }

  Future<void> subscribeUser(User user) async {
    final accountCubit = BlocProvider.of<AccountCubit>(context);
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    final str = S.of(context);
    final blockingOverlay = BlockingOverlay.of(context);
    accountCubit.startSubscribing(user);
    blockingOverlay.show(const CircularProgressIndicator(), Duration(seconds: 0));
    // activePurchaseItem can be out of date, especially if user cancelled subscription outside of
    // app just before it expired and then the app detected the expiry and pushes user here to resolve.
    // Probably in practice that will not happen much since they will sign into the app again much later, if ever!
    if (PaymentService.instance.activePurchaseItem != null) {
      await handlePurchaseItem(
        PaymentService.instance.activePurchaseItem!,
        KeeVaultPlatform.isAndroid,
        blockingOverlay,
        accountCubit,
        vaultCubit,
        str,
      );
      return;
    }
    try {
      if (iap?.products.isEmpty ?? true) {
        // This is known to happen when Apple are being unreliable in delivery of IAP subscriptions
        // for purchase. Such as when they randomly require new agreements to be signed with no notice.
        // Although we should now be unable to reach this point if that has happened we double-check now.
        throw Exception('No products found');
      }
      await PaymentService.instance.buyProduct(iap!.products[0], iap!.offerTokenIndex);
    } on Exception {
      setState(() {
        saving = false;
      });
      try {
        blockingOverlay.hide();
      } on Exception {
        if (mounted) {
          BlockingOverlay.of(context).hide();
        }
      }
    }
  }

  Future<void> registerAccount(String email, String password, bool marketingEmails) async {
    final blockingOverlay = BlockingOverlay.of(context);
    blockingOverlay.show(null, Duration(seconds: 1));
    final accountCubit = BlocProvider.of<AccountCubit>(context);
    User user;
    try {
      user = await accountCubit.createUserAccount(email, password, marketingEmails, KeeVaultPlatform.isAndroid ? 2 : 3);
    } on KeeException catch (e) {
      setState(() {
        registrationErrorMessage = e.cause;
        saveError = true;
        saving = false;
      });
      try {
        blockingOverlay.hide();
      } on Exception {
        if (mounted) {
          BlockingOverlay.of(context).hide();
        }
      }
      return;
    }
    await subscribeUser(user);
  }

  String resubscriptionNeededReason(AccountAuthenticated state) {
    if (state is AccountSubscribeError) {
      return 'Could not subscribe you this time. Please try again. Reason: ${(state).message}';
    }
    if (state is AccountExpired) {
      return 'Your subscription has expired.';
    }
    if (PaymentService.instance.activePurchaseItem != null) {
      return 'We found a Kee Vault subscription on this device. We will attach it to the new Kee Vault account when you press the button below.';
    }
    return 'Your account is enabled but you have no active subscription. That could happen for a variety of reasons but is easy to fix - just hit the button below and follow any steps your Subscription Provider presents.';
  }

  bool isRenewalMode(AccountAuthenticated state) {
    if (state is AccountSubscribeError) {
      return false;
    }
    if (state is AccountExpired) {
      return true;
    }
    if (PaymentService.instance.activePurchaseItem != null) {
      return false;
    }
    return true;
  }
}

class AccountCreateWrapperWidget extends StatelessWidget {
  const AccountCreateWrapperWidget({
    super.key,
    required this.widget,
    required this.mainContent,
    required this.mainTitle,
    required this.skipBackCheck,
    required this.saving,
  });

  final AccountCreateWidget widget;
  final Widget mainContent;
  final String mainTitle;
  final bool skipBackCheck;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return ColouredSafeArea(
      child: Scaffold(
        key: widget.key,
        appBar: AppBar(title: Text(mainTitle)),
        body: PopScope(
          canPop: skipBackCheck,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            if (didPop) {
              return;
            }
            final vc = BlocProvider.of<VaultCubit>(context);
            final ac = BlocProvider.of<AccountCubit>(context);
            final NavigatorState navigator = Navigator.of(context);
            final result = await showDialog(
              routeSettings: RouteSettings(),
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Cancel registration?'),
                content: Text(
                  'If you are part way through the account registration process, we cannot be sure whether your registration has completed or not, nor whether your Subscription provider has activated your subscription already. In that case, you may need to take additional actions to complete registration later or tidy up afterwards.',
                ),
                actions: <Widget>[
                  OutlinedButton(
                    child: Text('Cancel registration'.toUpperCase()),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                  OutlinedButton(
                    child: Text('Continue registering'.toUpperCase()),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            );
            if (result) {
              // sign out so user can see initial signin/register page again.
              await ac.forgetUser(vc.signout);
              navigator.pop();
            }
          },
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SafeArea(top: false, left: false, child: mainContent),
            ),
          ),
        ),
      ),
    );
  }
}
