import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sareemart_customer/core/responsive.dart';

/// Automated viewport matrix for the profiles from the Phase 16.2 plan.
/// Verifies the shared `Responsive` breakpoints behave at every listed size.
/// Screen-level behaviour (checkout CTA pinning in short heights) is covered
/// by `checkout_landscape_cta_test.dart`.
void main() {
  const profiles = <String, Size>{
    'Small phone 320x568': Size(320, 568),
    'Compact phone 360x640': Size(360, 640),
    'Standard phone 393x852': Size(393, 852),
    'Large phone 430x932': Size(430, 932),
    'Foldable cover 320x880': Size(320, 880),
    'Wide cover 420x900': Size(420, 900),
    'Unfolded foldable 673x841': Size(673, 841),
    'Large unfolded 800x900': Size(800, 900),
    'Small tablet 600x960': Size(600, 960),
    'Tablet landscape 960x600': Size(960, 600),
    'Large tablet 1200x800': Size(1200, 800),
  };

  for (final entry in profiles.entries) {
    testWidgets(entry.key, (tester) async {
      final collected = <String, Object?>{};
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: entry.value),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                collected['grid'] = Responsive.gridCount(context);
                collected['padding'] = Responsive.horizontalPadding(context);
                collected['isTablet'] = Responsive.isTablet(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final w = entry.value.width;
      expect(collected['grid'], w >= 900 ? 4 : (w >= 600 ? 3 : 2));
      expect(collected['isTablet'], w >= 600);
      expect((collected['padding'] as num) >= 16, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
