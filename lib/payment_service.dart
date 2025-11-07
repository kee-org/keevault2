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
  StreamSubscription<ConnectionResult>? _connectionSubscription;

  /// To listen the status of the purchase made inside or outside of the app (App Store / Play Store)
  ///
  /// If status is not error then app will be notified by this stream
  StreamSubscription<PurchasedItem?>? _purchaseUpdatedSubscription;

  /// To listen the errors of the purchase
  StreamSubscription<PurchaseResult?>? _purchaseErrorSubscription;

  /// List of product ids you want to fetch
  final List<String> _productIds = KeeVaultPlatform.isAndroid
      ? ['supporter', 'supporter-monthly', 'supporter-yearly']
      : ['sub.supporter.yearly'];

  /// All available products will be store in this list
  List<IAPItem>? _products;

  /// view of the app will subscribe to this to get errors of the purchase
  final ObserverList<Function(String)> _errorListeners = ObserverList<Function(String)>();

  /// view of the app will subscribe to this to get notified when a purchased is completed
  final ObserverList<Function(PurchasedItem)> _purchasedListeners = ObserverList<Function(PurchasedItem)>();

  PurchasedItem? _activePurchaseItem;
  PurchasedItem? get activePurchaseItem => _activePurchaseItem;

  void deferPurchaseItem(PurchasedItem? item) {
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
  void addToPurchasedListeners(Function(PurchasedItem) callback) {
    _purchasedListeners.add(callback);
  }

  /// view can cancel to _purchasedListeners using this method
  void removeFromPurchasedListeners(Function(PurchasedItem) callback) {
    _purchasedListeners.remove(callback);
  }

  /// Call this method to notify all the subscribers of completed purchases
  void _callPurchasedListeners(PurchasedItem item) {
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
      await FlutterInappPurchase.instance.initialize();

      _connectionSubscription = FlutterInappPurchase.connectionUpdated.listen((connected) {});
      _purchaseUpdatedSubscription = FlutterInappPurchase.purchaseUpdated.listen(_handlePurchaseUpdate);
      _purchaseErrorSubscription = FlutterInappPurchase.purchaseError.listen(_handlePurchaseError);

      await _getItems();
      _activePurchaseItem = await _getPastPurchases();
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
    await _connectionSubscription?.cancel();
    await _purchaseErrorSubscription?.cancel();
    await _purchaseUpdatedSubscription?.cancel();
    await FlutterInappPurchase.instance.finalize();
  }

  // Must be called on iOS because Apple don't offer a server API to confirm that
  // a purchase has been handled.
  Future<void> finishTransaction(PurchasedItem purchasedItem) async {
    if (KeeVaultPlatform.isIOS) {
      await FlutterInappPurchase.instance.finishTransaction(purchasedItem);
      // if above fails, we'll not remove the purchasedItem from the queue. If we did
      // we would risk not responding to App Store update notifications even if there
      // is only a transient problem.
      PaymentService.instance.deferPurchaseItem(null);
    }
  }

  void _handlePurchaseError(PurchaseResult? purchaseError) {
    _callErrorListeners(purchaseError?.message ?? '');
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
  void _handlePurchaseUpdate(PurchasedItem? productItem) async {
    if (productItem == null) return;
    if (KeeVaultPlatform.isAndroid) {
      await _handlePurchaseUpdateAndroid(productItem);
    } else {
      await _handlePurchaseUpdateIOS(productItem);
    }
  }

  Future<void> _handlePurchaseUpdateIOS(PurchasedItem purchasedItem) async {
    switch (purchasedItem.transactionStateIOS) {
      case TransactionState.deferred:
        // Edit: This was a bug that was pointed out here : https://github.com/dooboolab/flutter_inapp_purchase/issues/234
        // FlutterInappPurchase.instance.finishTransaction(purchasedItem);
        break;
      case TransactionState.failed:
        _callErrorListeners('Transaction Failed');
        await FlutterInappPurchase.instance.finishTransaction(purchasedItem);
        break;
      case TransactionState.purchased:
        if (purchasedItem.transactionDate == null) {
          l.e('Purchased Item contained no transaction date. Will auto-finish it since it must be an iOS bug or fraud');
          await FlutterInappPurchase.instance.finishTransaction(purchasedItem);
          break;
        }

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
            if (purchasedItem.transactionDate!.isBefore(_activePurchaseItem!.transactionDate!)) {
              await FlutterInappPurchase.instance.finishTransaction(purchasedItem);
              break;
            } else if (purchasedItem.transactionDate!.isAfter(_activePurchaseItem!.transactionDate!)) {
              // Have to make sure we update this now because may be some time before iOS completes
              // the transaction finish request and more purchasedItems may arrive in the mean time.
              final itemToFinish = _activePurchaseItem!;
              _activePurchaseItem = purchasedItem;
              await FlutterInappPurchase.instance.finishTransaction(itemToFinish);
              break;
            }
          }
          _activePurchaseItem = purchasedItem;
        } else {
          _callPurchasedListeners(purchasedItem);
        }
        break;
      case TransactionState.purchasing:
        break;
      case TransactionState.restored:
        // It looks like we are never notified of this anyway (transaction is finished in native
        // code) but doesn't matter since user's authorisation is tied to their Kee Vault
        // Account rather than anything specific to this device so restorations do not need
        // to be considered in any way.
        await FlutterInappPurchase.instance.finishTransaction(purchasedItem);
        break;
      default:
    }
  }

  /// three purchase state https://developer.android.com/reference/com/android/billingclient/api/Purchase.PurchaseState
  /// 0 : UNSPECIFIED_STATE
  /// 1 : PURCHASED
  /// 2 : PENDING
  Future<void> _handlePurchaseUpdateAndroid(PurchasedItem purchasedItem) async {
    switch (purchasedItem.purchaseStateAndroid) {
      case PurchaseState.purchased:
        _callPurchasedListeners(purchasedItem);
        break;
      default:
        _callErrorListeners('Something went wrong');
    }
  }

  Future<List<IAPItem>> get products async {
    if (_products == null) {
      await _getItems();
    }
    return _products!;
  }

  Future<void> _getItems() async {
    List<IAPItem> items = await FlutterInappPurchase.instance.getSubscriptions(_productIds);
    _products = [];
    for (var item in items) {
      l.d('IAP item found: ${item.productId}');
      _products!.add(item);
    }
    l.d('${_products!.length} IAP items found.');
  }

  Future<PurchasedItem?> _getPastPurchases() async {
    // pending purchases in iOS are continually pushed to the purchase
    // stream so we mustn't go looking for them explicitly
    if (KeeVaultPlatform.isIOS) {
      return null;
    }
    List<PurchasedItem> purchasedItems = await FlutterInappPurchase.instance.getAvailablePurchases() ?? [];

    for (var purchasedItem in purchasedItems) {
      // Assumes only one active subscription at a time. Which should be the case for foreseeable future.
      return purchasedItem;
    }
    return null;
  }

  Future<void> buyProduct(IAPItem item, int offerTokenIndex) async {
    await FlutterInappPurchase.instance.requestSubscription(item.productId!, offerTokenIndex: offerTokenIndex);
  }
}
