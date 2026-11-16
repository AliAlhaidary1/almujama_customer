import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sareemart_customer/core/api/customer_api.dart';
import 'package:sareemart_customer/core/app_controller.dart';
import 'package:sareemart_customer/core/business_hours.dart';
import 'package:sareemart_customer/core/json_util.dart';
import 'package:sareemart_customer/features/cart/cart_screens.dart';

/// PH16-002 regression: on compact-height windows the place-order CTA must be
/// reachable without scrolling (pinned bottom bar); on tall windows it stays
/// inline at the end of the form. Never both at once.
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

class _LandscapeApi extends CustomerApi {
  _LandscapeApi() : super(baseUrl: 'http://test.invalid');

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
}

Future<void> _pumpCheckoutAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = _LandscapeApi();
  appController.injectForTest(prefs: prefs, testApi: api);
  addTearDown(() async {
    appController.overrideConnectivityForTest(true);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  appController.city = {'id': 1, 'latitude': 15.0, 'longitude': 45.0};
  appController.businessHours = BusinessHoursResult();
  appController.token = 'tok';
  appController.user = {'id': 7, 'name': 'T', 'balance': 0};
  appController.settings = {
    'currency': 'ر.ي',
    'decimal_point': 2,
    'min_order_amount': 0,
    'max_sellers_per_checkout': 0,
    'web_settings': <String, dynamic>{},
  };
  appController.paymentSettings = {'cod_payment_method': '1'};
  appController.cartProducts = [_row()];
  appController.cartSubTotal = 200;
  appController.cart = {'cart': [_row()], 'sub_total': 200, 'final_total': 200};
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

  await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('compact landscape (568x320): CTA pinned, no scroll needed', (
    tester,
  ) async {
    await _pumpCheckoutAt(tester, const Size(568, 320));
    expect(find.byKey(const ValueKey('checkout-place-order')), findsOneWidget);
    // Pinned bar means the CTA is on screen without any scrolling.
    final rect = tester.getRect(
      find.byKey(const ValueKey('checkout-place-order')),
    );
    expect(rect.top >= 0 && rect.bottom <= 320, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone landscape (852x393): CTA pinned, no scroll needed', (
    tester,
  ) async {
    await _pumpCheckoutAt(tester, const Size(852, 393));
    expect(find.byKey(const ValueKey('checkout-place-order')), findsOneWidget);
    final rect = tester.getRect(
      find.byKey(const ValueKey('checkout-place-order')),
    );
    expect(rect.top >= 0 && rect.bottom <= 393, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet landscape (960x600): CTA stays inline', (tester) async {
    await _pumpCheckoutAt(tester, const Size(960, 600));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('checkout-place-order')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('checkout-place-order')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait standard (393x852): CTA inline at end of form', (
    tester,
  ) async {
    await _pumpCheckoutAt(tester, const Size(393, 852));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('checkout-place-order')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('checkout-place-order')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
