import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';
import 'package:keevault/logging/logger.dart';
import './config/platform.dart';

class PaymentService {
  /// We want singleton object of ``PaymentService`` so create private constructor
  ///
  /// Use PaymentService as ``PaymentService.instance``
  PaymentService._internal();

  static final PaymentService instance = PaymentService._internal();

  /// To listen the status of connection between app and the billing server
  //late final _connectionSubscription;

  /// To listen the status of the purchase made inside or outside of the app (App Store / Play Store)
  ///
  /// If status is not error then app will be notified by this stream
  StreamSubscription<Purchase>? _purchaseUpdatedSubscription;

  /// To listen the errors of the purchase
  StreamSubscription<PurchaseError>? _purchaseErrorSubscription;

  /// List of product ids you want to fetch
  final List<String> _productIds = KeeVaultPlatform.isAndroid
      ? ['supporter', 'supporter-monthly', 'supporter-yearly']
      : ['sub.supporter.yearly'];

  /// All available products will be store in this list
  List<ProductSubscription>? _products;

  /// view of the app will subscribe to this to get errors of the purchase
  final ObserverList<Function(String)> _errorListeners = ObserverList<Function(String)>();

  /// view of the app will subscribe to this to get notified when a purchased is completed
  final ObserverList<Function(Purchase)> _purchasedListeners = ObserverList<Function(Purchase)>();

  Purchase? _activePurchaseItem;
  Purchase? get activePurchaseItem => _activePurchaseItem;

  void deferPurchaseItem(Purchase? item) {
    _activePurchaseItem = item;
  }

  /// view can subscribe to _errorListeners using this method
  void addToErrorListeners(Function(String) callback) {
    _errorListeners.add(callback);
  }

  /// view can cancel to _errorListeners using this method
  void removeFromErrorListeners(Function(String) callback) {
    _errorListeners.remove(callback);
  }

  /// view can subscribe to _purchasedListeners using this method
  void addToPurchasedListeners(Function(Purchase) callback) {
    _purchasedListeners.add(callback);
  }

  /// view can cancel to _purchasedListeners using this method
  void removeFromPurchasedListeners(Function(Purchase) callback) {
    _purchasedListeners.remove(callback);
  }

  /// Call this method to notify all the subscribers of completed purchases
  void _callPurchasedListeners(Purchase item) {
    for (var callback in _purchasedListeners) {
      callback(item);
    }
  }

  /// Call this method to notify all the subscribers of _errorListeners
  void _callErrorListeners(String error) {
    for (var callback in _errorListeners) {
      callback(error);
    }
  }

  Future<void>? readyFuture;

  /// Call this method at app startup to initialize connection
  /// with billing server and get all the necessary data
  Future<void> initConnection() async {
    readyFuture = Future(() async {
      await FlutterInappPurchase.instance.initConnection();

      //_connectionSubscription = FlutterInappPurchase.instance.connectionUpdated.listen((connected) {});
      _purchaseUpdatedSubscription = FlutterInappPurchase.instance.purchaseUpdatedListener.listen(
        _handlePurchaseUpdate,
      );
      _purchaseErrorSubscription = FlutterInappPurchase.instance.purchaseErrorListener.listen(_handlePurchaseError);

      await _getItems();
      _activePurchaseItem = await _getPastPurchase();
    });
    await ensureReady();
  }

  Future<bool> ensureReady() async {
    if (readyFuture == null) {
      throw Exception('Call initConnection first!');
    }
    try {
      await readyFuture;
      return true;
    } on Exception {
      return false;
    }
  }

  /// call when user close the app
  void dispose() async {
    //await _connectionSubscription?.cancel();
    await _purchaseErrorSubscription?.cancel();
    await _purchaseUpdatedSubscription?.cancel();
    await FlutterInappPurchase.instance.endConnection();
  }

  // Must be called on iOS because Apple don't offer a server API to confirm that
  // a purchase has been handled.
  Future<void> finishTransaction(Purchase purchasedItem) async {
    if (KeeVaultPlatform.isIOS) {
      await FlutterInappPurchase.instance.finishTransaction(purchase: purchasedItem.toInput());
      // if above fails, we'll not remove the purchasedItem from the queue. If we did
      // we would risk not responding to App Store update notifications even if there
      // is only a transient problem.
      PaymentService.instance.deferPurchaseItem(null);
    }
  }

  void _handlePurchaseError(PurchaseError purchaseError) {
    _callErrorListeners(purchaseError.message);
  }

  /// Called when new updates arrives at ``purchaseUpdated`` stream
  /// Can happen in Android after user completes the IAP flow and also if they buy
  /// the subscription directly from the play store, however, in that situation
  /// it is more likely than not that the app is currently closed and therefore
  /// no message will be received here (instead we find out when we query all
  /// current active subscriptions at startup)
  /// Can happen in iOS at any time and appears to keep sending the same message
  /// again and again so we need to be able to de-dup. Once we call "finish transaction"
  /// they will stop sending them.
  void _handlePurchaseUpdate(Purchase? productItem) async {
    if (productItem == null) return;
    if (KeeVaultPlatform.isAndroid) {
      await _handlePurchaseUpdateAndroid(productItem as PurchaseAndroid);
    } else {
      await _handlePurchaseUpdateIOS(productItem as PurchaseIOS);
    }
  }

  Future<void> _handlePurchaseUpdateIOS(PurchaseIOS purchase) async {
    // iOS purchase updates with valid tokens indicate successful purchases
    final bool condition1 = purchase.iosTransactionState == TransactionState.purchased;
    bool condition2 = purchase.purchaseToken != null && purchase.purchaseToken!.isNotEmpty;
    final bool condition3 = purchase.transactionIdFor != null;
    if (condition1 || condition2 || condition3) {
      // Could interrupt user to say that their subscription is ready but it will often be
      // a renewing subscription and they could be in the middle of something critical so
      // that would be a bad user experience and we therefore leave it up to them to handle
      // it when they are ready to do so. Alternatively, we will automatically dismiss the
      // queued payment item on iOS once they next authenticate / sign-in.
      if (_purchasedListeners.isEmpty) {
        // If purchased date is different than our current pending purchase item, confirm the older
        // transaction straight away since it must be out of date info (e.g. a renewal purchase has since
        // superseded it so we have no use for the old information).
        // If dates are an exact match we just go with whatever the latest item iOS supplies,
        // although it is most likely to just be a duplicate of what we already have.
        if (_activePurchaseItem != null) {
          if (purchase.transactionDate < _activePurchaseItem!.transactionDate) {
            await FlutterInappPurchase.instance.finishTransaction(purchase: purchase);
            return;
          } else if (purchase.transactionDate > _activePurchaseItem!.transactionDate) {
            // Have to make sure we update this now because may be some time before iOS completes
            // the transaction finish request and more purchasedItems may arrive in the mean time.
            final itemToFinish = _activePurchaseItem!;
            _activePurchaseItem = purchase;
            await FlutterInappPurchase.instance.finishTransaction(purchase: itemToFinish);
            return;
          }
        }
        _activePurchaseItem = purchase;
      } else {
        _callPurchasedListeners(purchase);
      }
    } else {
      switch (purchase.iosTransactionState) {
        case TransactionState.deferred:
          // Edit: This was a bug that was pointed out here : https://github.com/dooboolab/flutter_inapp_purchase/issues/234
          // FlutterInappPurchase.instance.finishTransaction(purchasedItem);
          break;
        case TransactionState.failed:
          _callErrorListeners('Transaction Failed');
          await FlutterInappPurchase.instance.finishTransaction(purchase: purchase);
          break;
        case TransactionState.purchasing:
          break;
        case TransactionState.restored:
          // It looks like we are never notified of this anyway (transaction is finished in native
          // code) but doesn't matter since user's authorisation is tied to their Kee Vault
          // Account rather than anything specific to this device so restorations do not need
          // to be considered in any way.
          await FlutterInappPurchase.instance.finishTransaction(purchase: purchase);
          break;
        default:
      }
    }
  }

  /// three purchase state https://developer.android.com/reference/com/android/billingclient/api/Purchase.PurchaseState
  /// 0 : UNSPECIFIED_STATE
  /// 1 : PURCHASED
  /// 2 : PENDING
  Future<void> _handlePurchaseUpdateAndroid(PurchaseAndroid purchase) async {
    // For Android, check multiple conditions since fields can be null
    final bool condition1 = purchase.purchaseState == PurchaseState.Purchased;
    final bool condition2 =
        purchase.androidIsAcknowledged == false &&
        purchase.purchaseToken != null &&
        purchase.purchaseToken!.isNotEmpty &&
        purchase.purchaseState == PurchaseState.Purchased;
    final bool condition3 = purchase.androidPurchaseStateValue == AndroidPurchaseState.Purchased.value;

    if (condition1 || condition2 || condition3) {
      _callPurchasedListeners(purchase);
    }
  }

  Future<List<ProductSubscription>> get products async {
    if (_products == null) {
      await _getItems();
    }
    return _products!;
  }

  Future<void> _getItems() async {
    final items = await FlutterInappPurchase.instance.fetchProducts<ProductSubscription>(
      skus: _productIds,
      type: ProductQueryType.Subs,
    );
    _products = [];
    for (var item in items) {
      l.d('IAP item found: ${item.id}');
      _products!.add(item);
    }
    l.d('${_products!.length} IAP items found.');
  }

  Future<Purchase?> _getPastPurchase() async {
    // pending purchases in iOS are continually pushed to the purchase
    // stream so we mustn't go looking for them explicitly
    //TODO:f: Possibly with Storekit2 we could now do this and may be useful for
    // enabling purchasing from outside the normal flow... which is currently nonsensical.
    if (KeeVaultPlatform.isIOS) {
      return null;
    }
    List<Purchase> purchasedItems = await FlutterInappPurchase.instance.getAvailablePurchases();

    for (var purchasedItem in purchasedItems) {
      // Assumes only one active subscription at a time. Which should be the case for foreseeable future.
      return purchasedItem;
    }
    return null;
  }

  Future<void> buyProduct(ProductSubscription item, int offerTokenIndex) async {
    if (item is ProductSubscriptionAndroid) {
      final offer = (offerTokenIndex >= 0 && item.subscriptionOfferDetailsAndroid.length > offerTokenIndex)
          ? item.subscriptionOfferDetailsAndroid[offerTokenIndex]
          : null;
      final subsProps = RequestPurchaseProps.subs((
        ios: null, // RequestSubscriptionIosProps(sku: item.id),
        android: RequestSubscriptionAndroidProps(
          skus: [item.id],
          subscriptionOffers: offer != null
              ? [
                  AndroidSubscriptionOfferInput(
                    offerToken: offer.offerToken,
                    sku: offer
                        .offerId!, //TODO: is this correct? check openiap specs - maybe needs to be the broader item sku but problable correct.
                  ),
                ]
              : null,
        ),
        useAlternativeBilling: null,
      ));
      await FlutterInappPurchase.instance.requestPurchase(subsProps);
    }
    //TODO: ios
  }
}
