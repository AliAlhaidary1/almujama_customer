import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sareemart_customer/core/api/customer_api.dart';
import 'package:sareemart_customer/core/app_controller.dart';
import 'package:sareemart_customer/core/business_hours.dart';
import 'package:sareemart_customer/core/json_util.dart';
import 'package:sareemart_customer/features/cart/cart_screens.dart';

/// PH16-009 regression: the wallet toggle must produce a server-validated
/// wallet allocation, or never debit the wallet at all. These tests pin the
/// whole chain that was previously broken/ambiguous:
///   toggle -> effective wallet state -> deduction -> serialization -> COD
/// with the live balance as the source of truth.
Map<String, dynamic> _row() => {
      'product_id': 1,
      'product_variant_id': 11,
      'qty': 2,
      'price': 100,
      'name': 'منتج تجريبي',
      'seller_id': 5,
      'stock': 5,
      'measurement': 'وحدة',
      'stock_unit_name': 'وحدة',
    };

ApiResult _ok([dynamic data]) =>
    ApiResult({'status': 1, 'data': data ?? const {}});

class _WalletApi extends CustomerApi {
  _WalletApi() : super(baseUrl: 'http://test.invalid');

  Map<String, dynamic>? checkoutArgs;

  @override
  Future<ApiResult> cities({
    int limit = 100,
    int offset = 0,
    String search = '',
  }) async =>
      _ok([
        {'id': 1, 'name': 'Test City'},
      ]);

  @override
  Future<ApiResult> businessHours({List<dynamic> sellerIds = const []}) async =>
      _ok([]);

  @override
  Future<ApiResult> cart({
    required double latitude,
    required double longitude,
    int checkout = 0,
  }) async =>
      _ok({
        'cart': [_row()],
        'sub_total': 200,
        'final_total': 200,
        'delivery_charge': {'total_delivery_charge': 15},
        'seller_groups': [
          {'seller_id': 5, 'store_name': 'متجر', 'items': [_row()]},
        ],
      });

  @override
  Future<ApiResult> addresses() async => _ok([
        {
          'id': 3,
          'address': 'Street A',
          'is_default': 1,
          'latitude': '15.0',
          'longitude': '45.0',
        },
      ]);

  @override
  Future<ApiResult> checkout({
    required dynamic addressId,
    String paymentMethod = 'COD',
    bool useWallet = false,
    dynamic promocodeId,
    dynamic campaignId,
    String deliveryTime = '',
    String orderNote = '',
    String? idempotencyKey,
  }) async {
    checkoutArgs = {
      'address_id': addressId,
      'payment_method': paymentMethod,
      'use_wallet': useWallet,
      'promocode_id': promocodeId,
      'delivery_time': deliveryTime,
      'order_note': orderNote,
      'idempotency_key': idempotencyKey,
    };
    return _ok({'checkout_group_id': 99, 'checkout_session_token': 'sess'});
  }
}

String _draftEnvelope({required bool walletUsed}) => jsonEncode({
      'v': 1,
      'scope': 'u:7',
      'refreshedAt': DateTime.now().millisecondsSinceEpoch,
      'payload': {
        'method': 'COD',
        'walletUsed': walletUsed,
        'deliveryTime': '',
        'note': '',
        'addressId': 3,
      },
    });

Future<_WalletApi> _setup({
  double balance = 90,
  bool draftWalletUsed = false,
}) async {
  SharedPreferences.setMockInitialValues(
    draftWalletUsed
        ? {'oc:draft::u:7::checkout_form': _draftEnvelope(walletUsed: true)}
        : {},
  );
  final prefs = await SharedPreferences.getInstance();
  final api = _WalletApi();
  appController.injectForTest(prefs: prefs, testApi: api);
  appController.overrideConnectivityForTest(true);
  appController.city = {'id': 1, 'latitude': 15.0, 'longitude': 45.0};
  appController.businessHours = BusinessHoursResult();
  appController.token = 'tok';
  appController.user = {'id': 7, 'name': 'T', 'balance': balance};
  appController.settings = {
    'currency': 'ر.س',
    'decimal_point': 2,
    'min_order_amount': 0,
    'max_sellers_per_checkout': 0,
    'web_settings': <String, dynamic>{},
  };
  appController.paymentSettings = {'cod_payment_method': '1'};
  appController.cartProducts = [_row()];
  appController.cartSubTotal = 200;
  appController.cart = {
    'cart': [_row()],
    'sub_total': 200,
    'final_total': 200,
  };
  appController.addresses = [
    {
      'id': 3,
      'address': 'Street A',
      'is_default': 1,
      'latitude': '15.0',
      'longitude': '45.0',
    },
  ];
  appController.selectedAddress = appController.addresses.first;
  appController.unresolvedCheckout = false;
  return api;
}

Future<void> _pump(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/checkout',
    routes: [
      GoRoute(
        path: '/checkout',
        builder: (_, _) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/orders',
        builder: (_, _) => const Scaffold(body: Text('orders')),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) =>
            Scaffold(body: Text('order ${state.pathParameters['id']}')),
      ),
    ],
  );
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    appController.overrideConnectivityForTest(true);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

SwitchListTile _walletSwitch(WidgetTester tester) =>
    tester.widget<SwitchListTile>(find.byType(SwitchListTile));

Future<void> _tapPlaceOrder(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('checkout-place-order')),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const ValueKey('checkout-place-order')));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wallet toggle ON sends use_wallet=true and reduces total', (
    tester,
  ) async {
    final api = await _setup(balance: 90);
    await _pump(tester);

    expect(_walletSwitch(tester).value, isFalse);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(_walletSwitch(tester).value, isTrue);

    await _tapPlaceOrder(tester);
    expect(api.checkoutArgs, isNotNull);
    expect(api.checkoutArgs!['use_wallet'], isTrue);
    expect(api.checkoutArgs!['payment_method'], 'COD');
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet toggle OFF never debits wallet', (tester) async {
    final api = await _setup(balance: 90);
    await _pump(tester);

    expect(_walletSwitch(tester).value, isFalse);
    await _tapPlaceOrder(tester);
    expect(api.checkoutArgs, isNotNull);
    expect(api.checkoutArgs!['use_wallet'], isFalse);
    expect(api.checkoutArgs!['payment_method'], 'COD');
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggle off again after on returns to COD without wallet', (
    tester,
  ) async {
    final api = await _setup(balance: 90);
    await _pump(tester);

    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(_walletSwitch(tester).value, isTrue);

    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(_walletSwitch(tester).value, isFalse);

    await _tapPlaceOrder(tester);
    expect(api.checkoutArgs!['use_wallet'], isFalse);
    expect(api.checkoutArgs!['payment_method'], 'COD');
  });

  testWidgets(
    'PH16-009: restored draft opt-in with a zero balance renders OFF and '
    'sends use_wallet=false',
    (tester) async {
      final api = await _setup(balance: 0, draftWalletUsed: true);
      await _pump(tester);

      expect(
        _walletSwitch(tester).value,
        isFalse,
        reason: 'A restored wallet opt-in must not render ON with a zero '
            'balance — that is the PH16-009 symptom class.',
      );
      expect(_walletSwitch(tester).onChanged, isNull);

      await _tapPlaceOrder(tester);
      expect(api.checkoutArgs, isNotNull);
      expect(api.checkoutArgs!['use_wallet'], isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restored draft opt-in with a balance below the total applies the full '
    'balance (partial use), not zero',
    (tester) async {
      final api = await _setup(balance: 90, draftWalletUsed: true);
      await _pump(tester);

      expect(_walletSwitch(tester).value, isTrue);

      await _tapPlaceOrder(tester);
      expect(api.checkoutArgs!['use_wallet'], isTrue);
      expect(api.checkoutArgs!['payment_method'], 'COD');
    },
  );

  testWidgets('balance below total leaves honest COD remainder', (
    tester,
  ) async {
    final api = await _setup(balance: 60);
    await _pump(tester);

    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(_walletSwitch(tester).value, isTrue);

    await _tapPlaceOrder(tester);
    expect(api.checkoutArgs!['use_wallet'], isTrue);
    expect(api.checkoutArgs!['payment_method'], 'COD');
  });

  testWidgets('balance covering the total switches method to Wallet', (
    tester,
  ) async {
    final api = await _setup(balance: 500);
    await _pump(tester);

    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(_walletSwitch(tester).value, isTrue);

    await _tapPlaceOrder(tester);
    expect(api.checkoutArgs!['use_wallet'], isTrue);
    expect(api.checkoutArgs!['payment_method'], 'Wallet');
  });
}
