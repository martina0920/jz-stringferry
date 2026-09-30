import 'package:flutter_test/flutter_test.dart';

import 'package:jz_stringferry/core/theme/app_theme.dart';

void main() {
  test('品牌主题使用炭黑主色', () {
    final theme = AppTheme.light;
    expect(theme.colorScheme.primary, AppColors.ink);
    expect(theme.scaffoldBackgroundColor, AppColors.paper);
  });
}
