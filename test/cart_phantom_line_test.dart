import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:sareemart_customer/core/api/customer_api.dart';
import 'package:sareemart_customer/core/app_controller.dart';
import 'package:sareemart_customer/core/business_hours.dart';
import 'package:sareemart_customer/core/json_util.dart';

ApiResult _ok([dynamic data]) =>
    ApiResult({'status': 1, 'data': data ?? const {}});

class _FakeEmptyCartApi extends CustomerApi {
  _FakeEmptyCartApi() : super(baseUrl: 'http://test.invalid');

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
  Future<ApiResult> cart({
    required double latitude,
    required double longitude,
    int checkout = 0,
  }) async {
    return ApiResult({
      'status': 0,
      'message': 'لم يتم العثور على عناصر في عربة المستخدم',
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reachable empty Arabic cart wipes local phantom lines', () async {
    SharedPreferences.setMockInitialValues({
      'oc:snap::cart::u:7': jsonEncode({
        'v': 1,
        'scope': 'u:7',
        'refreshedAt': DateTime.now().millisecondsSinceEpoch,
        'payload': {
          'products': [
            {
              'product_id': 4,
              'product_variant_id': 2,
              'seller_id': 1,
              'qty': 1,
              'name': 'phantom bag',
            }
          ],
          'subTotal': 225.0,
        },
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final api = _FakeEmptyCartApi();
    appController.injectForTest(prefs: prefs, testApi: api);
    appController.overrideConnectivityForTest(true);
    appController.city = {'id': 1, 'latitude': 15.0, 'longitude': 44.0};
    appController.businessHours = BusinessHoursResult();
    appController.token = 'tok';
    appController.user = {'id': 7, 'name': 'T', 'balance': 90};
    appController.settings = {
      'currency': 'ر.س',
      'decimal_point': 2,
      'min_order_amount': 0,
      'max_sellers_per_checkout': 0,
      'web_settings': <String, dynamic>{},
    };
    appController.paymentSettings = {'cod_payment_method': '1'};
    appController.cartProducts = [
      {'product_id': 4, 'product_variant_id': 2, 'qty': 1, 'name': 'phantom bag'},
    ];
    appController.cartSubTotal = 225;

    await appController.refreshCart(checkout: 0);

    expect(appController.cartProducts, isEmpty);
    expect(appController.cartCount, 0);
  });
}
