import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thj_app/core/api.dart';
import 'package:thj_app/core/ui.dart';

void main() {
  test('api helpers tolerate missing fields', () {
    expect(asInt(null), 0);
    expect(asInt('12'), 12);
    expect(asStr(null, 'x'), 'x');
    expect(asBool('1'), isTrue);
    expect(asList(null), isEmpty);
  });

  testWidgets('app colors are defined', (tester) async {
    expect(AppColors.brand, isNotNull);
  });
}
