import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sareemart_customer/core/delivery_fee_label.dart';

/// Delivery-fee label honesty (PH16-003):
/// the UI may claim "free delivery" only when the effective charge is zero.
/// A free-delivery benefit (is_free_delivery=1) with a capped offer may still
/// leave a nonzero fee — that case must read as "discount applied".
void main() {
  String tAr(String key) => {
        'free_delivery': 'توصيل مجاني',
        'delivery_discount_applied': 'خصم توصيل مطبَّق',
        'delivery_charge': 'رسوم التوصيل',
      }[key]!;
  String tEn(String key) => {
        'free_delivery': 'Free delivery',
        'delivery_discount_applied': 'Delivery discount applied',
        'delivery_charge': 'Delivery Charge',
      }[key]!;

  group('deliveryFeeBadge', () {
    test('zero fee without benefit -> free', () {
      expect(
        deliveryFeeBadge(fee: 0, isFreeDeliveryBenefit: false),
        DeliveryFeeBadge.free,
      );
    });

    test('zero fee with benefit -> free (fully waived offer)', () {
      expect(
        deliveryFeeBadge(fee: 0, isFreeDeliveryBenefit: true),
        DeliveryFeeBadge.free,
      );
    });

    test('nonzero fee without benefit -> none', () {
      expect(
        deliveryFeeBadge(fee: 5.5, isFreeDeliveryBenefit: false),
        DeliveryFeeBadge.none,
      );
    });

    test('nonzero fee with capped benefit -> discountApplied, never "free"', () {
      expect(
        deliveryFeeBadge(fee: 3.25, isFreeDeliveryBenefit: true),
        DeliveryFeeBadge.discountApplied,
      );
    });

    test('negative fee defensive -> free', () {
      expect(
        deliveryFeeBadge(fee: -0.01, isFreeDeliveryBenefit: true),
        DeliveryFeeBadge.free,
      );
    });
  });

  group('deliveryFeeSuffix labels', () {
    test('Arabic: zero fee shows مجاني suffix', () {
      expect(
        deliveryFeeSuffix(
          fee: 0,
          isFreeDeliveryBenefit: true,
          t: tAr,
        ),
        ' (توصيل مجاني)',
      );
    });

    test('Arabic: capped offer shows خصم توصيل applied, not مجاني', () {
      final suffix = deliveryFeeSuffix(
        fee: 3.25,
        isFreeDeliveryBenefit: true,
        t: tAr,
      );
      expect(suffix, isNot(contains('مجاني')));
      expect(suffix, ' (خصم توصيل مطبَّق)');
    });

    test('English: zero fee shows free suffix', () {
      expect(
        deliveryFeeSuffix(
          fee: 0,
          isFreeDeliveryBenefit: false,
          t: tEn,
        ),
        ' (Free delivery)',
      );
    });

    test('English: capped offer shows Delivery discount applied', () {
      expect(
        deliveryFeeSuffix(
          fee: 3.25,
          isFreeDeliveryBenefit: true,
          t: tEn,
        ),
        ' (Delivery discount applied)',
      );
    });

    test('English: full fee without benefit shows no suffix', () {
      expect(
        deliveryFeeSuffix(
          fee: 8.0,
          isFreeDeliveryBenefit: false,
          t: tEn,
        ),
        '',
      );
    });
  });

  group('i18n assets carry the labels used by the checkout summary', () {
    test('ar.json and en.json contain delivery_charge, free_delivery and delivery_discount_applied', () {
      for (final path in ['assets/i18n/ar.json', 'assets/i18n/en.json']) {
        final raw = File(path).readAsStringSync();
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        expect(decoded['delivery_charge'], isNotEmpty, reason: path);
        expect(decoded['free_delivery'], isNotEmpty, reason: path);
        expect(decoded['delivery_discount_applied'], isNotEmpty, reason: path);
      }
    });
  });
}
