import 'package:flutter_test/flutter_test.dart';

bool looksEmpty(String message) {
  final m = message.toLowerCase();
  if (m.isEmpty) return false;
  return m.contains('no item') ||
      m.contains('no_item') ||
      m.contains('لم يتم العثور') ||
      m.contains('لا توجد عناصر');
}

void main() {
  test('empty cart message matches', () {
    expect(looksEmpty("لم يتم العثور على عناصر في عربة المستخدم"), isTrue);
  });
}
